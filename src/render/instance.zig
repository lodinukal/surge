const std = @import("std");

const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Instance = opaque {
    pub const Error = error{
        InstanceFailedToCreate,
    };

    pub const Descriptor = struct {
        debug: bool = @import("builtin").mode == .Debug,
    };

    pub inline fn createSurface(
        self: *Instance,
        allocator: std.mem.Allocator,
        desc: *const gpu.Surface.Descriptor,
    ) gpu.Surface.Error!*gpu.Surface {
        return impl.instanceCreateSurface(
            self,
            allocator,
            desc,
        );
    }

    pub inline fn requestPhysicalDevice(
        self: *Instance,
        allocator: std.mem.Allocator,
        desc: *const gpu.PhysicalDevice.Options,
    ) gpu.PhysicalDevice.Error!*gpu.PhysicalDevice {
        return impl.instanceRequestPhysicalDevice(
            self,
            allocator,
            desc,
        );
    }

    pub inline fn destroy(self: *Instance) void {
        impl.instanceDestroy(self);
    }
};
