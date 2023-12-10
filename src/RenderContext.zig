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
    // projection: math.Mat = math.identity(),
    // view: math.Mat = math.identity(),
    // model: math.Mat = math.identity(),
    rotation: f32 = 0,
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

mutex: std.Thread.Mutex = .{},

swapchain: *gpu.SwapChain = undefined,
swapchain_size: [2]u32 = .{ 800, 600 },
swapchain_format: gpu.Texture.Format = .undefined,
views: [3]?*const gpu.TextureView = .{ null, null, null },
view_count: usize = 0,

// rendering objects

arena: std.heap.ArenaAllocator = undefined,

vertex_buffer: ?*gpu.Buffer = null,
vertex_count: usize = 0,

index_buffer: ?*gpu.Buffer = null,
index_count: usize = 0,

uniform_buffer: ?*gpu.Buffer = null,
uniform_count: usize = 0,
uniforms: Uniforms = .{},

pipeline_layout: ?*gpu.PipelineLayout = null,

bind_group_layout: ?*gpu.BindGroupLayout = null,
bind_group: ?*gpu.BindGroup = null,

render_pipeline: ?*gpu.RenderPipeline = null,

render_pass: RenderPass = .{},

pub fn load(self: *RenderContext, allocator: std.mem.Allocator, window: *app.window.Window) !void {
    if (gpu.loadBackend(.d3d12) == false) return;
    self.arena = std.heap.ArenaAllocator.init(allocator);
    const instance = try gpu.createInstance(self.arena.allocator(), &.{});
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
    std.log.info("final {}", .{self.arena.queryCapacity()});
    self.cleanResources();

    self.swapchain.destroy();
    self.device.destroy();
    self.physical_device.destroy();
    self.surface.destroy();
    self.instance.destroy();

    std.log.info("hmm {}", .{self.arena.queryCapacity()});
    self.arena.deinit();
}

pub fn resize(self: *RenderContext, size: [2]u32) !void {
    _ = self;
    _ = size;

    // self.swapchain_size = size;
    // try self.swapchain.resize(size);

    // self.cleanupRenderPass();
    // try self.setupPass();

    // try self.rebuildCommandBuffers();
}

pub fn present(self: *RenderContext) !void {
    try self.swapchain.present();
}

fn loadResources(self: *RenderContext) !void {
    try self.loadViews();
    std.log.info("views loaded {}", .{self.arena.queryCapacity()});
    try self.prepareVertexAndIndexBuffers();
    std.log.info("buffers prepared {}", .{self.arena.queryCapacity()});
    try self.setupPipelineLayout();
    std.log.info("pipeline layout set up {}", .{self.arena.queryCapacity()});
    try self.prepareUniformBuffers();
    std.log.info("uniforms prepared {}", .{self.arena.queryCapacity()});
    try self.setupBindGroups();
    std.log.info("bind groups set up {}", .{self.arena.queryCapacity()});
    try self.setupPass();
    std.log.info("passes set up {}", .{self.arena.queryCapacity()});
    try self.preparePipelines();
    std.log.info("pipelines prepared {}", .{self.arena.queryCapacity()});
}

fn cleanResources(self: *RenderContext) void {
    if (self.vertex_buffer) |b| b.destroy();
    if (self.index_buffer) |b| b.destroy();

    if (self.bind_group) |bg| bg.destroy();
    if (self.bind_group_layout) |bgl| bgl.destroy();

    if (self.uniform_buffer) |b| b.destroy();
    if (self.pipeline_layout) |pl| pl.destroy();

    if (self.render_pipeline) |rp| rp.destroy();

    self.cleanupRenderPass();
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

fn setupPass(self: *RenderContext) !void {
    const render_pass = &self.render_pass;

    render_pass.colour_attachments[0] = gpu.RenderPass.ColourAttachment{
        .view = null,
        .load_op = .clear,
        .store_op = .store,
        .clear_value = .{
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        },
    };

    try render_pass.depth.init(self, .{});

    render_pass.descriptor = gpu.RenderPass.Descriptor{
        .label = "rp!",
        .colour_attachments = &render_pass.colour_attachments,
        .depth_stencil_attachment = &render_pass.depth.attachment_desc,
    };
}

fn cleanupRenderPass(self: *RenderContext) void {
    self.render_pass.deinit();
}

fn prepareUniformBuffers(self: *RenderContext) !void {
    self.uniform_buffer = try self.createUploadedBuffer(.{
        .uniform = true,
    }, Uniforms, &.{self.uniforms});
    errdefer self.uniform_buffer.?.destroy();

    try self.updateUniformBuffers();
}

fn updateUniformBuffers(self: *RenderContext) !void {
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
    const primitive_state = gpu.PrimitiveState{
        .topology = .triangle_list,
        .front_face = .ccw,
        .cull_mode = .none,
    };

    const blend_state = createBlendState(true);
    const colour_target_state = gpu.ColourTargetState{
        .format = self.swapchain_format,
        .blend = &blend_state,
        .write_mask = gpu.ColourWriteMaskFlags.all,
    };

    const depth_stencil_state = createDepthStencilState(&.{
        .format = .depth24_plus_stencil8,
        .depth_write_enabled = true,
    });

    const triangle_vertex_buffer_layout = gpu.VertexBufferLayout.fromStruct(
        Vertex,
        .{
            .position = .{ 0, .float32x4 },
            .colour = .{ 1, .float32x4 },
        },
    );

    const shader_module = try self.device.createShaderModule(&gpu.ShaderModule.Descriptor{
        .label = "trishader!",
        .code = hlsl_shader,
        .source_type = .hlsl,
    });
    defer shader_module.destroy();

    const vertex_state = gpu.VertexState{
        .module = shader_module,
        .entry_point = "vs_main",
        .buffers = &.{
            triangle_vertex_buffer_layout,
        },
    };

    const fragment_state = gpu.FragmentState{ .module = shader_module, .entry_point = "ps_main", .targets = &.{
        colour_target_state,
    } };

    const multisample_state = gpu.MultisampleState{};

    const pipeline_desc = gpu.RenderPipeline.Descriptor{
        .label = "rp!",
        .layout = self.pipeline_layout.?,
        .primitive = primitive_state,
        .vertex = vertex_state,
        .fragment = &fragment_state,
        .depth_stencil = &depth_stencil_state,
        .multisample = multisample_state,
    };

    self.render_pipeline = try self.device.createRenderPipeline(&pipeline_desc);
}

const hlsl_shader =
    \\
    \\struct Uniforms
    \\{
    \\   float rotation;
    \\};
    \\
    \\cbuffer un : register(b0) { Uniforms un; }
    \\
    \\struct InputVS
    \\{
    \\    float2 position : LOC0;
    \\    float3 color : LOC1;
    \\};
    \\
    \\struct OutputVS
    \\{
    \\    float4 position : SV_Position;
    \\    float3 color : COLOR;
    \\};
    \\
    \\// Vertex shader main function
    \\OutputVS vs_main(InputVS inp)
    \\{
    \\    OutputVS outp;
    \\    // rotate vertices around 0,0 by un.rotation degrees
    \\    float s = sin(un.rotation);
    \\    float c = cos(un.rotation);
    \\    float2x2 rot = float2x2(c, -s, s, c);
    \\    outp.position = float4(mul(rot, inp.position), 0, 1);
    \\    outp.color = inp.color;
    \\    return outp;
    \\}
    \\
    \\// Pixel shader main function
    \\float4 ps_main(OutputVS inp) : SV_Target
    \\{
    \\    return float4(inp.color, 1);
    \\};
;

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

fn prepareCommandBuffer(self: *RenderContext) !*gpu.CommandBuffer {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.render_pass.colour_attachments[0].view = self.swapchain.getCurrentTextureView();

    const command_encoder = try self.device.createCommandEncoder(&.{
        .label = "ce!",
    });
    defer command_encoder.destroy();

    const render_pass_encoder = try command_encoder.beginRenderPass(
        &self.render_pass.descriptor,
    );
    defer render_pass_encoder.destroy();

    try render_pass_encoder.setPipeline(self.render_pipeline.?);
    render_pass_encoder.setBindGroup(0, self.bind_group.?, null);
    try render_pass_encoder.setViewport(
        0.0,
        0.0,
        @floatFromInt(self.swapchain_size[0]),
        @floatFromInt(self.swapchain_size[1]),
        0.0,
        1.1,
    );
    try render_pass_encoder.setScissorRect(
        0,
        0,
        self.swapchain_size[0],
        self.swapchain_size[1],
    );
    try render_pass_encoder.setVertexBuffer(
        0,
        self.vertex_buffer.?,
        null,
        null,
    );
    try render_pass_encoder.setIndexBuffer(
        self.index_buffer.?,
        .uint16,
        null,
        null,
    );

    render_pass_encoder.drawIndexed(
        self.index_count,
        null,
        null,
        null,
        null,
    );

    try render_pass_encoder.end();
    return try command_encoder.finish(null);
}

pub fn draw(self: *RenderContext) !void {
    // update
    const command_buffer = try self.prepareCommandBuffer();
    // defer command_buffer.destroy();

    self.uniforms.rotation = @mod((self.uniforms.rotation + 0.01), @as(f32, 360.0));
    try self.updateUniformBuffers();

    try self.queue.submit(&.{
        command_buffer,
    });
}
