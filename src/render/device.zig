const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Device = opaque {
    pub const Error = error{
        DeviceFailedToCreate,
    };

    pub const LostReason = enum {
        undefined,
        destroyed,
    };

    pub const LostCallback = *const fn (
        reason: LostReason,
        message: []const u8,
    ) void;

    pub const Descriptor = struct {
        label: []const u8,
        lost_callback: ?LostCallback = null,
    };

    pub fn deinit(self: *Device) void {
        impl.destroyDevice(self);
    }
};
