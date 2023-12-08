const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");

const gpu = @import("render/gpu.zig");

const RenderContext = @This();

/// Based off a wgpu-native example:
/// https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/triangle.c
pub const Vertex = struct {
    position: math.Vec,
    colour: math.Vec,
};

pub const Uniforms = struct {
    projection: math.Mat = math.identity(),
    view: math.Mat = math.identity(),
    model: math.Mat = math.identity(),
};

instance: *gpu.Instance = undefined,
surface: *gpu.Surface = undefined,
physical_device: *gpu.PhysicalDevice = undefined,
device: *gpu.Device = undefined,
queue: *gpu.Queue = undefined,

swapchain: *gpu.SwapChain = undefined,
views: [3]?*const gpu.TextureView = .{ null, null, null },
view_count: usize = 0,

// rendering objects

vertex_buffer: ?*gpu.Buffer = null,
vertex_count: usize = 0,

index_buffer: ?*gpu.Buffer = null,
index_count: usize = 0,

uniform_buffer: ?*gpu.Buffer = null,
uniform_count: usize = 0,
uniforms: Uniforms = .{},

pipeline_layout: ?*gpu.PipelineLayout = null,

render_pipeline: ?*gpu.RenderPipeline = null,

render_pass: struct {
    colour_attachment: [1]gpu.RenderPass.ColourAttachment = .{undefined},
    descriptor: gpu.RenderPass.Descriptor = .{},
} = .{},

bind_group_layout: ?*gpu.BindGroupLayout = null,
bind_group: ?*gpu.BindGroup = null,

pub fn load(self: *RenderContext, allocator: std.mem.Allocator, window: *app.window.Window) !void {
    if (gpu.loadBackend(.d3d12) == false) return;
    const instance = try gpu.createInstance(allocator, &.{});
    errdefer instance.destroy();

    const surface = try instance.createSurface(&.{
        .native_handle = window.getNativeHandle().wnd,
        .native_handle_size = 8,
    });
    errdefer surface.destroy();

    const physicalDevice = try instance.requestPhysicalDevice(&.{
        .power_preference = .high_performance,
    });
    errdefer physicalDevice.destroy();

    const device = try physicalDevice.createDevice(&.{ .label = "device" });
    errdefer device.destroy();

    const swapchain = try device.createSwapChain(surface, &.{
        .height = 600,
        .width = 800,
        .present_mode = .mailbox,
        .format = .bgra8_unorm,
        .usage = .{
            .render_attachment = true,
        },
    });
    errdefer swapchain.destroy();

    self.instance = instance;
    self.surface = surface;
    self.physical_device = physicalDevice;
    self.device = device;
    self.queue = device.getQueue();
    self.swapchain = swapchain;

    try self.loadResources();
}

pub fn deinit(self: *RenderContext) void {
    self.cleanResources();

    self.swapchain.destroy();
    self.device.destroy();
    self.physical_device.destroy();
    self.surface.destroy();
    self.instance.destroy();
}

fn loadResources(self: *RenderContext) !void {
    try self.loadViews();
    try self.prepareVertexAndIndexBuffers();
    try self.setupPipelineLayout();
    try self.prepareUniformBuffers();
}

fn cleanResources(self: *RenderContext) void {
    if (self.vertex_buffer) |b| b.destroy();
    if (self.index_buffer) |b| b.destroy();

    if (self.bind_group) |bg| bg.destroy();
    if (self.bind_group_layout) |bgl| bgl.destroy();

    if (self.uniform_buffer) |b| b.destroy();
    if (self.pipeline_layout) |pl| pl.destroy();
    // if (self.render_pipeline) |rp| rp.destroy();
}

fn loadViews(self: *RenderContext) !void {
    self.view_count = try self.swapchain.getTextureViews(&self.views);
}

fn createUploadedBuffer(self: *RenderContext, usage: gpu.Buffer.UsageFlags, comptime T: type, data: []const T) !*gpu.Buffer {
    var modified_usage = usage;
    modified_usage.copy_dst = true;
    var buffer = try self.device.createBuffer(&.{
        .usage = modified_usage,
        .size = data.len * @sizeOf(T),
    });
    errdefer buffer.destroy();

    try self.queue.writeBuffer(buffer, 0, T, data);

    return buffer;
}

fn prepareVertexAndIndexBuffers(self: *RenderContext) !void {
    const vertices = [3]Vertex{
        .{
            .position = .{ 0.0, 0.5, 0.0, 0.0 },
            .colour = .{ 1.0, 0.0, 0.0, 1.0 },
        },
        .{
            .position = .{ 0.5, -0.5, 0.0, 0.0 },
            .colour = .{ 0.0, 1.0, 0.0, 1.0 },
        },
        .{
            .position = .{ -0.5, -0.5, 0.0, 0.0 },
            .colour = .{ 0.0, 0.0, 1.0, 1.0 },
        },
    };
    self.vertex_count = vertices.len;

    const indices = [4]u16{ 0, 1, 2, 0 };
    self.index_count = indices.len;

    self.vertex_buffer = try self.createUploadedBuffer(.{
        .vertex = true,
    }, Vertex, &vertices);

    self.index_buffer = try self.createUploadedBuffer(.{
        .index = true,
    }, u16, &indices);
}

fn setupPipelineLayout(self: *RenderContext) !void {
    self.bind_group_layout = try self.device.createBindGroupLayout(&.{
        .label = "bgl!",
        .entries = &.{
            gpu.BindGroupLayout.Entry.buffer(
                0,
                gpu.ShaderStageFlags.vertex,
                .uniform,
                false,
                @sizeOf(Uniforms),
            ),
        },
    });

    self.pipeline_layout = try self.device.createPipelineLayout(&gpu.PipelineLayout.Descriptor{
        .label = "pl!",
        .bind_group_layouts = &.{self.bind_group_layout.?},
    });
}

fn prepareUniformBuffers(self: *RenderContext) !void {
    self.uniform_buffer = try self.createUploadedBuffer(.{
        .uniform = true,
    }, Uniforms, &.{self.uniforms});
    errdefer self.uniform_buffer.?.destroy();

    try self.updateUniformBuffers();
}

fn updateUniformBuffers(self: *RenderContext) !void {
    std.debug.print("updateUniformBuffers\n", .{});
    // TODO: Make a camera
    // self.uniforms.model = math.rotateZ(math.identity(), std.time.timestamp() / 1000000000.0);
    // self.uniforms.view = math.translate(math.identity(), .{ 0.0, 0.0, -2.0 });
    // self.uniforms.projection = math.perspective(math.radians(45.0), 800.0 / 600.0, 0.1, 100.0);

    try self.queue.writeBuffer(
        self.uniform_buffer.?,
        0,
        Uniforms,
        &.{self.uniforms},
    );
}

fn setupBindGroups(self: *RenderContext) !void {
    self.bind_group = try self.device.createBindGroup(&gpu.BindGroup.Descriptor{
        .label = "bg!",
        .layout = self.bind_group_layout.?,
        .entries = &.{
            gpu.BindGroup.Entry.fromBuffer(
                0,
                self.uniform_buffer.?,
                0,
                @sizeOf(Uniforms),
                @sizeOf(Uniforms),
            ),
        },
    });
}
