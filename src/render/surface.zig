const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Surface = opaque {
    pub const Error = error{
        SurfaceFailedToCreate,
    };

    pub const Descriptor = struct {
        native_handle: *anyopaque,
        native_handle_size: usize,
    };

    pub inline fn destroy(self: *Surface) void {
        impl.surfaceDestroy(self);
    }
};
