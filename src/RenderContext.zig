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

pub const RenderPass = struct {
    colour_attachments: [1]gpu.RenderPass.ColourAttachment = .{undefined},
    depth: DepthTexture = .{},
    descriptor: gpu.RenderPass.Descriptor = .{},

    pub fn deinit(self: *RenderPass) void {
        self.depth.deinit();
    }
};

const DepthTexture = struct {
    texture: ?*gpu.Texture = null,
    view: ?*gpu.TextureView = null,
    attachment_desc: gpu.RenderPass.DepthStencilAttachment = undefined,

    pub const Options = struct {
        format: gpu.Texture.Format = .depth24_plus_stencil8,
        sample_count: u32 = 1,
    };

    pub fn init(self: *DepthTexture, render_ctx: *RenderContext, options: Options) !void {
        if (self.texture != null) return;
        if (self.view != null) return;

        const format: gpu.Texture.Format = options.format;
        const sample_count = @max(1, options.sample_count);

        const texture_desc = gpu.Texture.Descriptor{
            .usage = .{
                .render_attachment = true,
                .copy_src = true,
            },
            .format = format,
            .dimension = .dimension_2d,
            .mip_level_count = 1,
            .sample_count = sample_count,
            .size = .{ .width = 800, .height = 600, .depth_or_array_layers = 1 },
        };
        self.texture = try render_ctx.device.createTexture(&texture_desc);

        const view_desc = gpu.TextureView.Descriptor{
            .format = texture_desc.format,
            .dimension = .dimension_2d,
            .aspect = .all,
            .base_mip_level = 0,
            .mip_level_count = 1,
            .base_array_layer = 0,
            .array_layer_count = 1,
        };
        self.view = try self.texture.?.createView(&view_desc);

        self.attachment_desc = gpu.RenderPass.DepthStencilAttachment{
            .view = self.view.?,
            .depth_load_op = .clear,
            .depth_store_op = .store,
            .depth_clear_value = 1.0,
            .stencil_clear_value = 0,
        };

        if (format == .depth24_plus_stencil8) {
            self.attachment_desc.stencil_load_op = .clear;
            self.attachment_desc.stencil_store_op = .store;
        }
    }

    pub fn deinit(self: *DepthTexture) void {
        if (self.texture) |t| t.destroy();
        if (self.view) |v| v.destroy();
    }
};

instance: *gpu.Instance = undefined,
surface: *gpu.Surface = undefined,
physical_device: *gpu.PhysicalDevice = undefined,
device: *gpu.Device = undefined,
queue: *gpu.Queue = undefined,

swapchain: *gpu.SwapChain = undefined,
swapchain_format: gpu.Texture.Format = .undefined,
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

render_passes: [3]RenderPass = .{ .{}, .{}, .{} },

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
    self.swapchain_format = .bgra8_unorm;

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
    try self.setupAllPasses();
    try self.preparePipelines();
}

fn cleanResources(self: *RenderContext) void {
    if (self.vertex_buffer) |b| b.destroy();
    if (self.index_buffer) |b| b.destroy();

    if (self.bind_group) |bg| bg.destroy();
    if (self.bind_group_layout) |bgl| bgl.destroy();

    if (self.uniform_buffer) |b| b.destroy();
    if (self.pipeline_layout) |pl| pl.destroy();

    for (0..self.view_count) |i| {
        self.render_passes[i].deinit();
    }
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

fn setupAllPasses(self: *RenderContext) !void {
    for (0..self.view_count) |i| {
        const view = self.views[i];
        const render_pass = &self.render_passes[i];

        render_pass.colour_attachments[0] = gpu.RenderPass.ColourAttachment{
            .view = view,
            .load_op = .clear,
            .store_op = .store,
            .clear_value = .{
                .r = 0.1,
                .g = 0.2,
                .b = 0.3,
                .a = 1.0,
            },
        };

        try render_pass.depth.init(self, .{});

        render_pass.descriptor = gpu.RenderPass.Descriptor{
            .label = "rp!",
            .colour_attachments = &render_pass.colour_attachments,
            .depth_stencil_attachment = render_pass.depth.attachment_desc,
        };
    }
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

fn preparePipelines(self: *RenderContext) !void {
    const primitive_state_desc = gpu.PrimitiveState{
        .topology = .triangle_list,
        .front_face = .ccw,
        .cull_mode = .none,
    };
    _ = primitive_state_desc;

    const blend_state = createBlendState(true);
    const colour_target_state_desc = gpu.ColourTargetState{
        .format = self.swapchain_format,
        .blend = &blend_state,
        .write_mask = gpu.ColourWriteMaskFlags.all,
    };
    _ = colour_target_state_desc;

    const depth_stencil_state_desc = createDepthStencilState(&.{
        .format = .depth24_plus_stencil8,
        .depth_write_enabled = true,
    });
    _ = depth_stencil_state_desc;

    const triangle_vertex_buffer_layout = gpu.VertexBufferLayout.fromStruct(
        Vertex,
        .{
            .position = .{ 0, .float32x4 },
            .colour = .{ 1, .float32x4 },
        },
    );
    std.debug.print("{}\n", .{triangle_vertex_buffer_layout});

    // TODO: Shaders!
    // const vertex_state_desc = wgpu
}

fn createBlendState(blendable: bool) gpu.BlendState {
    var blend_component_desc = gpu.BlendComponent{
        .operation = .add,
    };

    if (blendable) {
        blend_component_desc.src_factor = .src_alpha;
        blend_component_desc.dst_factor = .one_minus_src_alpha;
    } else {
        blend_component_desc.src_factor = .one;
        blend_component_desc.dst_factor = .zero;
    }

    return gpu.BlendState{
        .colour = blend_component_desc,
        .alpha = blend_component_desc,
    };
}

const DepthStencilStateOptions = struct {
    format: gpu.Texture.Format = .undefined,
    depth_write_enabled: bool = false,
};

fn createDepthStencilState(options: *const DepthStencilStateOptions) gpu.DepthStencilState {
    const stencil_state_face_descriptor = gpu.StencilFaceState{
        .compare = .always,
        .fail_op = .keep,
        .depth_fail_op = .keep,
        .pass_op = .keep,
    };

    return gpu.DepthStencilState{
        .depth_write_enabled = options.depth_write_enabled,
        .format = options.format,
        .depth_compare = .less_equal,
        .stencil_front = stencil_state_face_descriptor,
        .stencil_back = stencil_state_face_descriptor,
        .stencil_read_mask = 0xFFFFFFFF,
        .stencil_write_mask = 0xFFFFFFFF,
        .depth_bias = 0,
        .depth_bias_slope_scale = 0.0,
        .depth_bias_clamp = 0.0,
    };
}
