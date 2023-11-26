const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Instance = opaque {
    pub const Error = error{
        InstanceFailedToCreate,
    };

    pub fn createSurface(self: *Instance, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*gpu.Surface {
        return impl.instanceCreateSurface(self, desc);
    }

    pub fn deinit(self: *Instance) void {
        impl.destroyInstance(self);
    }
};
