const std = @import("std");
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
pub const Texture = opaque {};
pub const TextureView = opaque {};

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
