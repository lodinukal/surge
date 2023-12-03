const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const CommandBuffer = opaque {
    pub const Error = error{
        CommandBufferFailedToCreate,
        CommandBufferMapForUploadFailed,
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
    };

    pub inline fn destroy(self: *CommandBuffer) void {
        impl.commandBufferDestroy(self);
    }
};
