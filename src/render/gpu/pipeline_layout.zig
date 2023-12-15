const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const PipelineLayout = opaque {
    pub const Error = error{
        PipelineLayoutFailedToCreate,
        PipelineLayoutSerializeRootSignatureFailed,
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
        bind_group_layouts: ?[]const *gpu.BindGroupLayout = null,
    };

    pub inline fn destroy(self: *PipelineLayout) void {
        impl.pipelineLayoutDestroy(self);
    }
};
