const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Queue = opaque {
    pub const Descriptor = struct {
        label: []const u8,
    };

    pub fn deinit(self: *Queue) void {
        impl.destroyQueue(self);
    }
};
