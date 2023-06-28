const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const common = @import("../core/common.zig");
const input_enums = @import("../core/input_enums.zig");

const platform_window = switch (builtin.os.tag) {
    .windows => @import("windows/window.zig"),
    inline else => @panic("Unsupported OS"),
};

pub const WindowHandle = u32;

pub const WindowCreateInfo = struct {
    title: []const u8,
    rect: common.Rect2i,
    flags: WindowFlags,
    vsync: VsyncMode = VsyncMode.enabled,
    mode: WindowMode = WindowMode.windowed,
};

pub const VsyncMode = enum {
    disabled,
    enabled,
    adaptive,
    mailbox,
};

pub const WindowFlags = packed struct {
    resized_disabled: bool = false,
    borderless: bool = false,
    always_on_top: bool = false,
    transparent: bool = false,
    no_focus: bool = false,
    popup: bool = false,
    extend_to_title_bar: bool = false,
    mouse_passthrough: bool = false,
};

pub const WindowMode = enum {
    windowed,
    minimized,
    maximized,
    fullscreen,
    exclusive_fullscreen,
};

pub fn createWindow(info: WindowCreateInfo) !WindowHandle {
    return try platform_window.createWindow(info);
}

test "platwindow" {
    std.testing.refAllDeclsRecursive(platform_window);
}
