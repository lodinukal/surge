const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const PhysicalDevice = opaque {
    pub const Error = error{
        PhysicalDeviceFailedToCreate,
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

    pub const Vendor = enum(u32) {
        amd = 0x1002,
        apple = 0x106b,
        arm = 0x13B5,
        google = 0x1AE0,
        img_tec = 0x1010,
        intel = 0x8086,
        mesa = 0x10005,
        microsoft = 0x1414,
        nvidia = 0x10DE,
        qualcomm = 0x5143,
        samsung = 0x144d,
        _,
    };

    pub const Properties = struct {
        name: []const u8,
        vendor: Vendor,
    };

    pub inline fn createDevice(self: *PhysicalDevice, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*gpu.Device {
        return impl.physicalDeviceCreateDevice(self, desc);
    }

    pub inline fn getProperties(self: *PhysicalDevice, out_props: *Properties) bool {
        return impl.physicalDeviceGetProperties(self, out_props);
    }

    pub inline fn destroy(self: *PhysicalDevice) void {
        impl.physicalDeviceDestroy(self);
    }
};
