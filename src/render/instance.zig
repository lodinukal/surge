const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Instance = opaque {
    pub const Error = error{
        InstanceFailedToCreate,
    };

    pub const Descriptor = struct {
        debug: bool = @import("builtin").mode == .Debug,
    };

    pub fn createSurface(self: *Instance, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*gpu.Surface {
        return impl.instanceCreateSurface(self, desc);
    }

    pub fn requestAdapter(self: *Instance, desc: *const gpu.Adapter.Options) gpu.Adapter.Error!*gpu.Adapter {
        return impl.instanceRequestAdapter(self, desc);
    }

    pub fn deinit(self: *Instance) void {
        impl.destroyInstance(self);
    }
};
