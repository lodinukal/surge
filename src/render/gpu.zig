const std = @import("std");

const commonutil = @import("../util.zig");

pub const impl = @import("impl.zig");
// pub const impl = @import("d3d11/main.zig");
pub const procs = @import("procs.zig");
pub const util = @import("util.zig");

pub const loadBackend = if (@hasDecl(impl, "loadBackend")) impl.loadBackend else struct {
    pub fn load(backend: BackendType) bool {
        _ = backend;
        return true;
    }
}.load;
pub const closeBackend = if (@hasDecl(impl, "closeBackend")) impl.closeBackend else struct {
    pub fn close() void {}
}.close;

pub const createInstance = impl.createInstance;

pub const array_layer_count_undefined = 0xffffffff;
pub const copy_stride_undefined = 0xffffffff;
pub const limit_u32_undefined = 0xffffffff;
pub const limit_u64_undefined = 0xffffffffffffffff;
pub const mip_level_count_undefined = 0xffffffff;
pub const query_set_index_undefined = 0xffffffff;
pub const whole_map_size = std.math.maxInt(u64);
pub const whole_size = 0xffffffffffffffff;

pub const BindGroup = opaque {};
pub const BindGroupLayout = opaque {};
pub const Buffer = @import("buffer.zig").Buffer;
pub const CommandBuffer = @import("command_buffer.zig").CommandBuffer;
pub const CommandEncoder = @import("command_encoder.zig").CommandEncoder;
pub const ComputePassEncoder = opaque {};
pub const ComputePipeline = opaque {};
pub const Device = @import("device.zig").Device;
pub const Instance = @import("instance.zig").Instance;
pub const PhysicalDevice = @import("physical_device.zig").PhysicalDevice;
pub const PipelineLayout = opaque {};
pub const QuerySet = opaque {};
pub const Queue = @import("queue.zig").Queue;
pub const RenderBundle = opaque {};
pub const RenderBundleEncoder = opaque {};
pub const RenderPassEncoder = opaque {};
pub const RenderPipeline = opaque {};
pub const Sampler = opaque {};
pub const ShaderModule = opaque {};
pub const Surface = @import("surface.zig").Surface;
pub const SwapChain = @import("swap_chain.zig").SwapChain;
pub const Texture = @import("texture.zig").Texture;
pub const TextureView = @import("texture_view.zig").TextureView;

pub const Error = blk: {
    var err = error{};
    inline for (.{
        BindGroup,
        BindGroupLayout,
        Buffer,
        CommandBuffer,
        CommandEncoder,
        ComputePassEncoder,
        ComputePipeline,
        Device,
        Instance,
        PhysicalDevice,
        PipelineLayout,
        QuerySet,
        Queue,
        RenderBundle,
        RenderBundleEncoder,
        RenderPassEncoder,
        RenderPipeline,
        Sampler,
        ShaderModule,
        Surface,
        Texture,
        TextureView,
    }) |T| {
        if (@hasDecl(T, "Error")) {
            err = err || T.Error;
        }
    }

    break :blk err;
};

pub const ErrorEnum = commonutil.ErrorEnum(Error);

pub const BackendType = enum(u32) {
    undefined,
    null,
    webgpu,
    d3d11,
    d3d12,
    metal,
    vulkan,
    opengl,
    opengles,

    pub fn name(t: BackendType) []const u8 {
        return switch (t) {
            .undefined => "Undefined",
            .null => "Null",
            .webgpu => "WebGPU",
            .d3d11 => "D3D11",
            .d3d12 => "D3D12",
            .metal => "Metal",
            .vulkan => "Vulkan",
            .opengl => "OpenGL",
            .opengles => "OpenGLES",
        };
    }
};

pub const Extent3D = struct {
    width: u32,
    height: u32,
    depth_or_array_layers: u32,
};

pub const Origin3D = struct {
    x: u32,
    y: u32,
    z: u32,
};

pub const ImageCopyBuffer = extern struct {
    layout: Texture.DataLayout,
    buffer: *Buffer,
};

pub const ImageCopyTexture = extern struct {
    texture: *Texture,
    mip_level: u32 = 0,
    origin: Origin3D = .{},
    aspect: Texture.Aspect = .all,
};

pub const VertexFormat = enum(u32) {
    undefined = 0x00000000,
    uint8x2 = 0x00000001,
    uint8x4 = 0x00000002,
    sint8x2 = 0x00000003,
    sint8x4 = 0x00000004,
    unorm8x2 = 0x00000005,
    unorm8x4 = 0x00000006,
    snorm8x2 = 0x00000007,
    snorm8x4 = 0x00000008,
    uint16x2 = 0x00000009,
    uint16x4 = 0x0000000a,
    sint16x2 = 0x0000000b,
    sint16x4 = 0x0000000c,
    unorm16x2 = 0x0000000d,
    unorm16x4 = 0x0000000e,
    snorm16x2 = 0x0000000f,
    snorm16x4 = 0x00000010,
    float16x2 = 0x00000011,
    float16x4 = 0x00000012,
    float32 = 0x00000013,
    float32x2 = 0x00000014,
    float32x3 = 0x00000015,
    float32x4 = 0x00000016,
    uint32 = 0x00000017,
    uint32x2 = 0x00000018,
    uint32x3 = 0x00000019,
    uint32x4 = 0x0000001a,
    sint32 = 0x0000001b,
    sint32x2 = 0x0000001c,
    sint32x3 = 0x0000001d,
    sint32x4 = 0x0000001e,
};

pub const limits = struct {
    pub const max_texture_dimension1d: u32 = 8192;
    pub const max_texture_dimension2d: u32 = 8192;
    pub const max_texture_dimension3d: u32 = 2048;
    pub const max_texture_array_layers: u32 = 256;
    pub const max_bind_groups: u32 = 4;
    pub const max_bind_groups_plus_vertex_buffers: u32 = 24;
    pub const max_bindings_per_bind_group: u32 = 1000;
    pub const max_dynamic_uniform_buffers_per_pipeline_layout: u32 = 8;
    pub const max_dynamic_storage_buffers_per_pipeline_layout: u32 = 4;
    pub const max_sampled_textures_per_shader_stage: u32 = 16;
    pub const max_samplers_per_shader_stage: u32 = 16;
    pub const max_storage_buffers_per_shader_stage: u32 = 8;
    pub const max_storage_textures_per_shader_stage: u32 = 4;
    pub const max_uniform_buffers_per_shader_stage: u32 = 12;
    pub const max_uniform_buffer_binding_size: u64 = 65536;
    pub const max_storage_buffer_binding_size: u64 = 134217728;
    pub const min_uniform_buffer_offset_alignment: u32 = 256;
    pub const min_storage_buffer_offset_alignment: u32 = 256;
    pub const max_vertex_buffers: u32 = 8;
    pub const max_buffer_size: u64 = 268435456;
    pub const max_vertex_attributes: u32 = 16;
    pub const max_vertex_buffer_array_stride: u32 = 2048;
    pub const max_inter_stage_shader_components: u32 = 60;
    pub const max_inter_stage_shader_variables: u32 = 16;
    pub const max_color_attachments: u32 = 8;
    pub const max_color_attachment_bytes_per_sample: u32 = 32;
    pub const max_compute_workgroup_storage_size: u32 = 16384;
    pub const max_compute_invocations_per_workgroup: u32 = 256;
    pub const max_compute_workgroup_size_x: u32 = 256;
    pub const max_compute_workgroup_size_y: u32 = 256;
    pub const max_compute_workgroup_size_z: u32 = 64;
    pub const max_compute_workgroups_per_dimension: u32 = 65535;

    pub const max_buffers_per_shader_stage = max_storage_buffers_per_shader_stage + max_uniform_buffers_per_shader_stage;
};
