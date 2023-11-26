const std = @import("std");
pub const impl = @import("impl.zig");

pub const loadBackend = impl.loadBackend;
pub const closeBackend = impl.closeBackend;

pub const createInstance = impl.createInstance;

pub const array_layer_count_undefined = 0xffffffff;
pub const copy_stride_undefined = 0xffffffff;
pub const limit_u32_undefined = 0xffffffff;
pub const limit_u64_undefined = 0xffffffffffffffff;
pub const mip_level_count_undefined = 0xffffffff;
pub const query_set_index_undefined = 0xffffffff;
pub const whole_map_size = std.math.maxInt(u64);
pub const whole_size = 0xffffffffffffffff;

pub const Adapter = @import("adapter.zig").Adapter;
pub const BindGroup = opaque {};
pub const BindGroupLayout = opaque {};
pub const Buffer = opaque {};
pub const CommandBuffer = opaque {};
pub const CommandEncoder = opaque {};
pub const ComputePassEncoder = opaque {};
pub const ComputePipeline = opaque {};
pub const Device = opaque {};
pub const Instance = @import("instance.zig").Instance;
pub const PipelineLayout = opaque {};
pub const QuerySet = opaque {};
pub const Queue = opaque {};
pub const RenderBundle = opaque {};
pub const RenderBundleEncoder = opaque {};
pub const RenderPassEncoder = opaque {};
pub const RenderPipeline = opaque {};
pub const Sampler = opaque {};
pub const ShaderModule = opaque {};
pub const Surface = @import("surface.zig").Surface;
pub const Texture = opaque {};
pub const TextureView = opaque {};

pub const Error = Instance.Error || Surface.Error;

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
