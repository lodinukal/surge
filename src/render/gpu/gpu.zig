const std = @import("std");

const format = @import("format.zig");
const pool = @import("pool.zig");

pub const Error = error{
    InvalidHandle,
    DeviceLost,
};

pub const RendererType = enum {
    d3d12,
    gles,
    vulkan,
    metal,
    webgpu,
};

pub const Access = packed struct(u2) {
    read: bool = false,
    write: bool = false,

    pub fn readWrite(a: Access) bool {
        return a.read and a.write;
    }
};

pub const SymbolTable = struct {
    init: *const fn (*const u8, u32) ?*const u8,
};

test {
    std.testing.refAllDecls(format);
    std.testing.refAllDecls(pool);
}
