const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const CommandEncoder = opaque {
    pub const Error = error{
        CommandEncoderFailedToFinish,
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
    };

    pub inline fn destroy(self: *CommandEncoder) void {
        impl.commandEncoderDestroy(self);
    }
};
