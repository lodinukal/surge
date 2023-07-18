const builtin = @import("builtin");
pub const impl = switch (builtin.os.tag) {
    .windows => @import("./platform_impl/windows.zig"),
    inline else => @compileError("Unsupported OS"),
};
