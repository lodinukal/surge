const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Instance = opaque {
    pub const Error = error{
        InstanceFailedToCreate,
    };

    pub const Descriptor = struct {
        debug: bool = @import("builtin").mode == .Debug,
    };

    pub inline fn createSurface(self: *Instance, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*gpu.Surface {
        return impl.instanceCreateSurface(self, desc);
    }

    pub inline fn requestPhysicalDevice(self: *Instance, desc: *const gpu.PhysicalDevice.Options) gpu.PhysicalDevice.Error!*gpu.PhysicalDevice {
        return impl.instanceRequestPhysicalDevice(self, desc);
    }

    pub inline fn destroy(self: *Instance) void {
        impl.instanceDestroy(self);
    }
};
