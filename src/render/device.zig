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

    pub inline fn getQueue(self: *Device) *gpu.Queue {
        return impl.deviceGetQueue(self);
    }

    pub inline fn createBuffer(self: *Device, descriptor: *const gpu.Buffer.Descriptor) !*gpu.Buffer {
        return try impl.deviceCreateBuffer(self, descriptor);
    }

    pub inline fn destroy(self: *Device) void {
        impl.deviceDestroy(self);
    }
};
