const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Queue = opaque {
    pub const Error = error{
        QueueFailedToCreate,
        QueueFailedToSubmit,
    };

    pub const Descriptor = struct {
        label: []const u8,
    };
};
