const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");

const common = @import("core/common.zig");

const gpu = @import("gpu/gpu.zig");
const image = @import("image.zig");

const RenderContext = @This();

/// Based off a wgpu-native example:
/// https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/triangle.c
pub const Vertex = struct {
    position: math.Vec,
    tex_coords: [2]f32,
};

pub const Uniforms = struct {
    // projection: math.Mat = math.identity(),
    // view: math.Mat = math.identity(),
    // model: math.Mat = math.identity(),
    rotation: f32 = 0,
    resolution: [2]f32 = .{ 1, 1 },
    uv_clip: f32 = 0,
};

pub const RenderPass = struct {
    colour_attachments: [1]gpu.RenderPass.ColourAttachment = .{undefined},
    depth_attachment: gpu.RenderPass.DepthStencilAttachment = undefined,
    descriptor: gpu.RenderPass.Descriptor = .{},

    pub fn deinit(self: *RenderPass) void {
        _ = self;
    }
};

instance: *gpu.Instance = undefined,
surface: *gpu.Surface = undefined,
physical_device: *gpu.PhysicalDevice = undefined,
device: *gpu.Device = undefined,
queue: *gpu.Queue = undefined,

mutex: std.Thread.Mutex = .{},

swapchain: *gpu.SwapChain = undefined,
swapchain_size: [2]u32 = .{ 0, 0 },
swapchain_format: gpu.Texture.Format = .undefined,
views: [3]?*const gpu.TextureView = .{ null, null, null },
view_count: usize = 0,

// rendering objects

permanent_arena: std.heap.ArenaAllocator = undefined,
resource_arena: std.heap.ArenaAllocator = undefined,
swapchain_arena: std.heap.ArenaAllocator = undefined,
frame_arena: std.heap.ArenaAllocator = undefined,

permanent_allocator: std.mem.Allocator = undefined,
resource_allocator: std.mem.Allocator = undefined,
swapchain_allocator: std.mem.Allocator = undefined,
frame_allocator: std.mem.Allocator = undefined,

vertex_buffer: ?*gpu.Buffer = null,
vertex_count: usize = 0,

index_buffer: ?*gpu.Buffer = null,
index_count: usize = 0,

uniform_buffer: ?*gpu.Buffer = null,
uniform_count: usize = 0,
uniforms: Uniforms = .{},

depth_texture: ?*gpu.Texture = null,
depth_texture_view: ?*gpu.TextureView = null,

reginleif_texture_a: ?*gpu.Texture = null,
reginleif_texture_view_a: ?*gpu.TextureView = null,
reginleif_sampler_a: ?*gpu.Sampler = null,

eye_blob_texture: ?*gpu.Texture = null,
eye_blob_texture_view: ?*gpu.TextureView = null,
eye_blob_sampler: ?*gpu.Sampler = null,

pipeline_layout: ?*gpu.PipelineLayout = null,

bind_group_layout_0: ?*gpu.BindGroupLayout = null,
bind_group_0: ?*gpu.BindGroup = null,

bind_group_layout_1: ?*gpu.BindGroupLayout = null,
bind_group_1: ?*gpu.BindGroup = null,

render_pass: RenderPass = .{},

render_pipeline: ?*gpu.RenderPipeline = null,

pub fn load(self: *RenderContext, allocator: std.mem.Allocator, window: *app.Window) !void {
    if (gpu.loadBackend(.d3d12) == false) return;
    self.permanent_arena = std.heap.ArenaAllocator.init(allocator);
    self.resource_arena = std.heap.ArenaAllocator.init(allocator);
    self.swapchain_arena = std.heap.ArenaAllocator.init(allocator);
    self.frame_arena = std.heap.ArenaAllocator.init(allocator);

    self.permanent_allocator = self.permanent_arena.allocator();
    self.resource_allocator = self.resource_arena.allocator();
    self.swapchain_allocator = self.swapchain_arena.allocator();
    self.frame_allocator = self.frame_arena.allocator();

    const instance = try gpu.createInstance(self.permanent_allocator, &.{});
    errdefer instance.destroy();

    const surface = try instance.createSurface(self.permanent_allocator, &.{
        .native_handle = window.getNativeHandle().wnd,
        .native_handle_size = 8,
    });
    errdefer surface.destroy();

    const physicalDevice = try instance.requestPhysicalDevice(self.permanent_allocator, &.{
        .power_preference = .high_performance,
    });
    errdefer physicalDevice.destroy();

    const device = try physicalDevice.createDevice(self.permanent_allocator, &.{ .label = "device" });
    errdefer device.destroy();

    const window_size = window.getContentSize();
    const swapchain = try device.createSwapChain(self.permanent_allocator, surface, &.{
        .height = window_size[0],
        .width = window_size[1],
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
    self.swapchain_size = window_size;
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

    self.permanent_arena.deinit();
    self.resource_arena.deinit();
    self.swapchain_arena.deinit();
    self.frame_arena.deinit();
}

pub fn resize(self: *RenderContext, size: [2]u32) !void {
    self.swapchain_size = size;
    if (size[0] == 0 and size[1] == 0) return; // suspend the game
    if (try self.swapchain.resize(size)) {
        // we resized, recreate the depth texture
        self.cleanupDepthTexture();
        try self.createDepthTexture(size);
        _ = self.swapchain_arena.reset(.retain_capacity);
    }
}

pub fn present(self: *RenderContext) !void {
    try self.swapchain.present();
}

fn loadResources(self: *RenderContext) !void {
    try self.loadViews();
    try self.createDepthTexture(self.swapchain_size);
    try self.prepareVertexAndIndexBuffers();
    try self.setupPipelineLayout();
    try self.prepareUniformBuffers();
    try self.loadReginleifTexture();
    try self.setupBindGroups();
    try self.preparePipelines();
}

fn cleanResources(self: *RenderContext) void {
    if (self.vertex_buffer) |b| b.destroy();
    if (self.index_buffer) |b| b.destroy();

    if (self.bind_group_0) |bg| bg.destroy();
    if (self.bind_group_layout_0) |bgl| bgl.destroy();

    if (self.bind_group_1) |bg| bg.destroy();
    if (self.bind_group_layout_1) |bgl| bgl.destroy();

    if (self.uniform_buffer) |b| b.destroy();
    if (self.pipeline_layout) |pl| pl.destroy();

    if (self.reginleif_sampler_a) |s| s.destroy();
    if (self.reginleif_texture_view_a) |tv| tv.destroy();
    if (self.reginleif_texture_a) |t| t.destroy();

    if (self.eye_blob_sampler) |s| s.destroy();
    if (self.eye_blob_texture_view) |tv| tv.destroy();
    if (self.eye_blob_texture) |t| t.destroy();

    if (self.render_pipeline) |rp| rp.destroy();

    self.cleanupRenderPass();
    self.cleanupDepthTexture();
}

fn loadViews(self: *RenderContext) !void {
    self.view_count = try self.swapchain.getTextureViews(&self.views);
}

fn createUploadedBuffer(
    self: *RenderContext,
    usage: gpu.Buffer.UsageFlags,
    comptime T: type,
    data: []const T,
    label: ?[]const u8,
) !*gpu.Buffer {
    var modified_usage = usage;
    modified_usage.copy_dst = true;
    var buffer = try self.device.createBuffer(self.resource_allocator, &.{
        .label = label,
        .usage = modified_usage,
        .size = data.len * @sizeOf(T),
    });
    errdefer buffer.destroy();

    try self.queue.writeBuffer(buffer, 0, T, data);

    return buffer;
}

fn loadTextureFromMemory(self: *RenderContext, memory: []const u8, info: image.Info) !*gpu.Texture {
    const size: gpu.Extent3D = .{
        .width = info.width,
        .height = info.height,
        .depth_or_array_layers = 1,
    };
    const tex = try self.device.createTexture(self.resource_allocator, &.{
        .size = size,
        .usage = .{
            .texture_binding = true,
            .copy_dst = true,
        },
        .mip_level_count = 1,
        .sample_count = 1,
        .format = .rgba8_unorm_srgb,
    });

    var dst = gpu.ImageCopyTexture{
        .texture = tex,
        .mip_level = 0,
        .origin = gpu.Origin3D.zero,
        .aspect = .all,
    };
    try self.queue.writeTexture(&dst, u8, memory, &.{
        .offset = 0,
        .bytes_per_row = info.channels * info.width,
        .rows_per_image = info.height,
    }, &size);

    return tex;
}

fn prepareVertexAndIndexBuffers(self: *RenderContext) !void {
    const vertices = [4]Vertex{
        .{ .position = .{ -1, -1, 0.0, 1.0 }, .tex_coords = .{ 0.0, 1.0 } },
        .{ .position = .{ 1, -1, 0.0, 1.0 }, .tex_coords = .{ 1.0, 1.0 } },
        .{ .position = .{ 1, 1, 0.0, 1.0 }, .tex_coords = .{ 1.0, 0.0 } },
        .{ .position = .{ -1, 1, 0.0, 1.0 }, .tex_coords = .{ 0.0, 0.0 } },
    };
    self.vertex_count = vertices.len;

    const indices = [6]u16{
        0, 1, 2,
        2, 3, 0,
    };
    self.index_count = indices.len;

    self.vertex_buffer = try self.createUploadedBuffer(.{
        .vertex = true,
    }, Vertex, &vertices, "vb!");

    self.index_buffer = try self.createUploadedBuffer(.{
        .index = true,
    }, u16, &indices, "ib!");
}

fn setupPipelineLayout(self: *RenderContext) !void {
    self.bind_group_layout_0 = try self.device.createBindGroupLayout(self.resource_allocator, &.{
        .label = "bgl1!",
        .entries = &.{
            gpu.BindGroupLayout.Entry.buffer(0, .{ .vertex = true }, .uniform, false, @sizeOf(Uniforms)),
        },
    });

    self.bind_group_layout_1 = try self.device.createBindGroupLayout(self.resource_allocator, &.{
        .label = "bgl2!",
        .entries = &.{
            gpu.BindGroupLayout.Entry.texture(0, .{ .fragment = true }, .uint, .dimension_2d, true, 2),
            gpu.BindGroupLayout.Entry.sampler(1, .{ .fragment = true }, .filtering, 2),
        },
    });

    self.pipeline_layout = try self.device.createPipelineLayout(self.resource_allocator, &.{
        .label = "pl!",
        .bind_group_layouts = &.{ self.bind_group_layout_0.?, self.bind_group_layout_1.? },
    });
}

fn setupBindGroups(self: *RenderContext) !void {
    self.bind_group_0 = try self.device.createBindGroup(self.resource_allocator, &gpu.BindGroup.Descriptor{
        .label = "bg!",
        .layout = self.bind_group_layout_0.?,
        .entries = &.{
            gpu.BindGroup.Entry.fromBuffers(0, &.{
                .{
                    .buffer = self.uniform_buffer.?,
                    .offset = 0,
                    .size = @sizeOf(Uniforms),
                },
            }),
        },
    });

    self.bind_group_1 = try self.device.createBindGroup(self.resource_allocator, &gpu.BindGroup.Descriptor{
        .label = "bg!",
        .layout = self.bind_group_layout_1.?,
        .entries = &.{
            gpu.BindGroup.Entry.fromTextureViews(0, &.{
                self.reginleif_texture_view_a.?,
                self.eye_blob_texture_view.?,
            }),
            gpu.BindGroup.Entry.fromSamplers(1, &.{
                self.reginleif_sampler_a.?,
                self.eye_blob_sampler.?,
            }),
        },
    });
}

fn createDepthTexture(self: *RenderContext, swapchain_size: [2]u32) !void {
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

    self.depth_texture = try self.device.createTexture(
        self.swapchain_allocator,
        &descriptor,
    );
    errdefer self.depth_texture.?.destroy();

    self.depth_texture_view = try self.depth_texture.?.createView(
        self.swapchain_allocator,
        &.{},
    );
}

fn cleanupDepthTexture(self: *RenderContext) void {
    if (self.depth_texture_view) |t| t.destroy();
    if (self.depth_texture) |t| t.destroy();
}

fn setupPass(self: *RenderContext) !void {
    const render_pass = &self.render_pass;

    render_pass.colour_attachments[0] = gpu.RenderPass.ColourAttachment{
        .view = self.swapchain.getCurrentTextureView(),
        .load_op = .clear,
        .store_op = .store,
        .clear_value = .{
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 1.0,
        },
    };

    render_pass.depth_attachment = gpu.RenderPass.DepthStencilAttachment{
        .view = self.depth_texture_view.?,
        .depth_load_op = .clear,
        .depth_store_op = .store,
        .depth_clear_value = 1.0,
        .stencil_clear_value = 0,
    };

    render_pass.descriptor = gpu.RenderPass.Descriptor{
        .label = "rp!",
        .colour_attachments = &render_pass.colour_attachments,
        .depth_stencil_attachment = &render_pass.depth_attachment,
    };
}

fn cleanupRenderPass(self: *RenderContext) void {
    self.render_pass.deinit();
}

fn prepareUniformBuffers(self: *RenderContext) !void {
    self.uniform_buffer = try self.createUploadedBuffer(.{
        .uniform = true,
    }, Uniforms, &.{self.uniforms}, "ub!");
    errdefer self.uniform_buffer.?.destroy();
}

fn updateUniformBuffers(self: *RenderContext) !void {
    // TODO: Make a camera
    // self.uniforms.model = math.rotateZ(math.identity(), std.time.timestamp() / 1000000000.0);
    // self.uniforms.view = math.translate(math.identity(), .{ 0.0, 0.0, -2.0 });
    // self.uniforms.projection = math.perspective(math.radians(45.0), 800.0 / 600.0, 0.1, 100.0);

    self.uniforms.uv_clip = @mod(self.uniforms.uv_clip + 0.01, 1.0);

    try self.queue.writeBuffer(
        self.uniform_buffer.?,
        0,
        Uniforms,
        &.{self.uniforms},
    );
}

const reginleif = @embedFile("reginleif.png");
const eye_blob = @embedFile("eye-blob.jpg");
fn loadReginleifTexture(self: *RenderContext) !void {
    var img_a = try image.Image.load(reginleif);
    defer img_a.deinit();

    self.reginleif_texture_a = try self.loadTextureFromMemory(
        img_a.data,
        img_a.info,
    );
    self.reginleif_texture_view_a = try self.reginleif_texture_a.?.createView(self.resource_allocator, &.{});
    self.reginleif_sampler_a = try self.device.createSampler(self.resource_allocator, &.{
        .label = "reginleif_sampler_a",
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
        .mag_filter = .linear,
        .min_filter = .nearest,
        .mipmap_filter = .nearest,
    });

    var img_b = try image.Image.load(eye_blob);
    defer img_b.deinit();

    self.eye_blob_texture = try self.loadTextureFromMemory(
        img_b.data,
        img_b.info,
    );
    self.eye_blob_texture_view = try self.eye_blob_texture.?.createView(self.resource_allocator, &.{});
    self.eye_blob_sampler = try self.device.createSampler(self.resource_allocator, &.{
        .label = "eye_blob_sampler",
        .address_mode_u = .clamp_to_edge,
        .address_mode_v = .clamp_to_edge,
        .address_mode_w = .clamp_to_edge,
        .mag_filter = .nearest,
        .min_filter = .linear,
        .mipmap_filter = .linear,
    });
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
            .tex_coords = .{ 1, .float32x2 },
        },
    );

    var scratch = common.ScratchSpace(4096){};
    const temp_allocator = scratch.init().allocator();

    const shader_module = try self.device.createShaderModule(temp_allocator, &gpu.ShaderModule.Descriptor{
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

    self.render_pipeline = try self.device.createRenderPipeline(self.resource_allocator, &pipeline_desc);
}

const hlsl_shader =
    \\
    \\struct Uniforms
    \\{
    \\   float rotation;
    \\   float2 resolution;
    \\   float uv_clip;
    \\};
    \\
    \\cbuffer un : register(b0) { Uniforms un; }
    \\
    \\// texture
    \\Texture2D g_textures[] : register(t0, space1);
    \\SamplerState g_samplers[] : register(s1, space1);
    \\
    \\struct InputVS
    \\{
    \\    float4 position : LOC0;
    \\    float2 tex_coords : LOC1;
    \\};
    \\
    \\struct OutputVS
    \\{
    \\    float4 position : SV_Position;
    \\    float2 tex_coords : TEXCOORD0;
    \\};
    \\
    \\// Vertex shader main function
    \\OutputVS vs_main(InputVS inp)
    \\{
    \\    OutputVS outp;
    \\    outp.position = inp.position;
    \\    outp.tex_coords = inp.tex_coords;
    \\    return outp;
    \\}
    \\
    \\// Pixel shader main function
    \\float4 ps_main(OutputVS inp) : SV_Target
    \\{
    \\    float const aspect = un.resolution.x / un.resolution.y;
    \\    float2 uv = inp.tex_coords;
    \\    uv -= 0.5;
    \\    uv.x *= aspect;
    \\    uv += 0.5;
    \\    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
    \\      discard;
    \\    }
    \\    int using_texture = uv.x > un.uv_clip ? 1 : 0;
    \\    float4 colour = g_textures[using_texture].Sample(g_samplers[using_texture], uv);
    \\    return colour;
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

    try self.setupPass();

    const command_encoder = try self.device.createCommandEncoder(self.frame_allocator, &.{
        .label = "ce!",
    });
    defer command_encoder.destroy();

    const render_pass_encoder = try command_encoder.beginRenderPass(
        self.frame_allocator,
        &self.render_pass.descriptor,
    );
    defer render_pass_encoder.destroy();

    try render_pass_encoder.setPipeline(self.render_pipeline.?);
    render_pass_encoder.setBindGroup(0, self.bind_group_0.?, null);
    render_pass_encoder.setBindGroup(1, self.bind_group_1.?, null);
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
    self.uniforms.resolution = .{ @as(f32, @floatFromInt(self.swapchain_size[0])), @as(f32, @floatFromInt(self.swapchain_size[1])) };
    try self.updateUniformBuffers();

    try self.queue.submit(&.{
        command_buffer,
    });

    _ = self.frame_arena.reset(.retain_capacity);
}
