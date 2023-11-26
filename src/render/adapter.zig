const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Adapter = opaque {
    pub const Error = error{
        AdapterFailedToCreate,
    };

    pub const PowerPreference = enum(u8) {
        undefined = 0,
        low_power = 1,
        high_performance = 2,
    };

    pub const Options = struct {
        compatible_surface: ?*gpu.Surface = null,
        power_preference: PowerPreference = .undefined,
    };

    pub fn deinit(self: *Adapter) void {
        impl.destroyAdapter(self);
    }
};
