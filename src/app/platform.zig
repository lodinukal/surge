const std = @import("std");
const builtin = @import("builtin");

pub const impl = switch (builtin.target.os.tag) {
    .windows => @import("windows.zig"),
    inline else => @compileError("Unsupported OS"),
};
