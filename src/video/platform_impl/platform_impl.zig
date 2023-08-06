const builtin = @import("builtin");
pub const impl = switch (builtin.os.tag) {
    .windows => @import("./windows/windows.zig"),
    inline else => @compileError("Unsupported OS"),
};

pub const Fullscreen = union(enum) {
    exclusive: impl.VideoMode,
    borderless: ?impl.DisplayHandle,
};
