const std = @import("std");
const gpu = @import("../gpu/gpu.zig");

const Window = @import("../app/app.zig").Window;

const Self = @This();

// whole
allocator: std.mem.Allocator,

instance: *gpu.Instance,
surface: *gpu.Surface,
physical_device: *gpu.PhysicalDevice,
device: *gpu.Device,
queue: *gpu.Queue,

// swapchain
swapchain_lifetime_arena: std.heap.ArenaAllocator,
swapchain_lifetime_allocator: std.mem.Allocator,

swapchain: *gpu.SwapChain,
swapchain_size: [2]u32 = .{ 0, 0 },
swapchain_format: gpu.Texture.Format = .undefined,
views: [3]?*const gpu.TextureView = .{ null, null, null },
view_count: usize = 0,

swapchain_present_resources: struct {
    depth: ?*gpu.Texture = null,
    depth_view: ?*const gpu.TextureView = null,
} = .{},
swapchain_renderpass_colour_attachments: [1]gpu.RenderPass.ColourAttachment = .{
    .{
        .view = null, // to be filled in when creating the swapchain
        .load_op = .clear,
        .store_op = .store,
        .clear_value = .{
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        },
    },
},
swapchain_renderpass_depth_attachment: gpu.RenderPass.DepthStencilAttachment = .{
    .view = undefined, // to be filled in when creating the depth path
    .depth_load_op = .clear,
    .depth_store_op = .store,
    .depth_clear_value = 1.0,
    .stencil_clear_value = 0,
},

// frame
frame_lifetime_arena: std.heap.ArenaAllocator,
frame_lifetime_allocator: std.mem.Allocator,

frame_in_progress: bool = false,
frame_command_encoder: ?*gpu.CommandEncoder = null,

pub fn init(allocator: std.mem.Allocator, window: *Window) !Self {
    if (!gpu.loadBackend(.d3d12)) return error.BackendLoadFailed;

    const instance = try gpu.createInstance(allocator, &.{});
    errdefer instance.destroy();

    const surface = try instance.createSurface(allocator, &.{
        .native_handle = window.getNativeHandle().wnd,
        .native_handle_size = 8,
    });
    errdefer surface.destroy();

    const physical_device = try instance.requestPhysicalDevice(allocator, &.{
        .power_preference = .high_performance,
    });
    errdefer physical_device.destroy();

    const device = try physical_device.createDevice(allocator, &.{ .label = "device" });
    errdefer device.destroy();

    const window_size = window.getContentSize();
    const swapchain = try device.createSwapChain(allocator, surface, &.{
        .height = window_size[0],
        .width = window_size[1],
        .present_mode = .mailbox,
        .format = .bgra8_unorm,
        .usage = .{
            .render_attachment = true,
        },
    });
    errdefer swapchain.destroy();

    const swapchain_lifetime_arena = std.heap.ArenaAllocator.init(allocator);
    const swapchain_lifetime_allocator = swapchain_lifetime_arena.allocator();

    const frame_lifetime_arena = std.heap.ArenaAllocator.init(allocator);
    const frame_lifetime_allocator = frame_lifetime_arena.allocator();

    return .{
        .allocator = allocator,
        .instance = instance,
        .surface = surface,
        .physical_device = physical_device,
        .device = device,
        .queue = device.getQueue(),

        .swapchain_lifetime_arena = swapchain_lifetime_arena,
        .swapchain_lifetime_allocator = swapchain_lifetime_allocator,
        .swapchain = swapchain,
        .swapchain_size = window_size,
        .swapchain_format = .bgra8_unorm,

        .frame_lifetime_arena = frame_lifetime_arena,
        .frame_lifetime_allocator = frame_lifetime_allocator,
    };
}

pub fn deinit(self: *Self) !void {
    self.cleanupSwapchainDependentResources(true);

    self.swapchain.destroy();
    self.device.destroy();
    self.physical_device.destroy();
    self.surface.destroy();
    self.instance.destroy();
}

fn createDepthTexture(self: *Self, swapchain_size: [2]u32) !void {
    const size = gpu.Extent3D{
        .width = swapchain_size[0],
        .height = swapchain_size[1],
        .depth_or_array_layers = 1,
    };
    const descriptor = gpu.Texture.Descriptor{
        .size = size,
        .usage = .{
            .render_attachment = true,
            .texture_binding = true,
        },
        .format = .depth24_plus_stencil8,
        .dimension = .dimension_2d,
        .mip_level_count = 1,
        .sample_count = 1,
    };

    self.swapchain_present_resources.depth = try self.device.createTexture(
        self.swapchain_lifetime_allocator,
        &descriptor,
    );
    errdefer self.swapchain_present_resources.depth.?.destroy();

    self.swapchain_present_resources.depth_view = try self.depth_texture.?.createView(
        self.swapchain_lifetime_allocator,
        &.{},
    );
    self.swapchain_renderpass_depth_attachment.view = self.swapchain_present_resources.depth_view.?;
}

fn cleanupDepthTexture(self: *Self) void {
    if (self.swapchain_present_resources.depth) |depth| {
        depth.destroy();
        self.swapchain_present_resources.depth = null;
    }
    if (self.swapchain_present_resources.depth_view) |depth_view| {
        depth_view.destroy();
        self.swapchain_present_resources.depth_view = null;
        self.swapchain_renderpass_depth_attachment.view = undefined;
    }
}

fn createSwapchainDependentResources(self: *Self) !void {
    const swapchain_size = self.swapchain_size;
    try self.createDepthTexture(swapchain_size);
}

fn cleanupSwapchainDependentResources(self: *Self, final: bool) void {
    self.cleanupDepthTexture();
    self.swapchain_lifetime_allocator.reset(if (final) .retain_capacity else .free_all);
}

fn recreateSwapchainDependentResources(self: *Self) !void {
    self.cleanupSwapchainDependentResources(false);
    try self.createSwapchainDependentResources();
}

pub fn resize(self: *Self, size: [2]u32) !void {
    if (size[0] == self.swapchain_size[0] and size[1] == self.swapchain_size[1]) return;
    if (size[0] == 0 or size[1] == 0) return;

    self.swapchain_size = size;
    if (try self.swapchain.resize(self.swapchain_size)) {
        try self.recreateSwapchainDependentResources();
    }
}

pub fn beginFrame(self: *Self) !void {
    std.debug.assert(!self.frame_in_progress);
    self.frame_in_progress = true;
    self.frame_command_encoder = try self.device.createCommandEncoder(self.frame_lifetime_allocator, &.{
        .label = "frame commands",
    });
}

pub fn endFrame(self: *Self) !void {
    std.debug.assert(self.frame_in_progress);
    self.frame_in_progress = false;

    const command_buffer = try self.frame_command_encoder.?.finish();
    command_buffer.destroy();
    self.frame_lifetime_arena.reset(.retain_capacity);
}

pub fn beginRenderPassAttachments(
    self: *Self,
    name: []const u8,
    colour_attachments: []const gpu.RenderPass.ColourAttachment,
    depth_attachment: ?*const gpu.RenderPass.DepthStencilAttachment,
) !*gpu.RenderPass.Encoder {
    std.debug.assert(self.frame_in_progress);

    const render_pass_encoder = try self.frame_command_encoder.?.beginRenderPass(self.frame_lifetime_allocator, &.{
        .label = name,
        .colour_attachments = colour_attachments,
        .depth_stencil_attachment = depth_attachment,
    });

    return render_pass_encoder;
}

pub fn beginRenderPass(
    self: *Self,
    name: []const u8,
) !*gpu.RenderPass.Encoder {
    self.swapchain_renderpass_descriptor.colour_attachments[0].view = self.swapchain.getCurrentTextureView();

    return self.beginRenderPassAttachments(
        name,
        &self.swapchain_renderpass_colour_attachments,
        &self.swapchain_renderpass_depth_attachment,
    );
}

pub fn endRenderPass(self: *Self, render_pass_encoder: *gpu.RenderPass.Encoder) void {
    std.debug.assert(self.frame_in_progress);
    try render_pass_encoder.end();
    render_pass_encoder.destroy();
}
