const std = @import("std");

const platform = @import("./platform_impl/platform_impl.zig");
const dpi = @import("dpi.zig");
const icon = @import("icon.zig");
const theme = @import("theme.zig");

const PlatformWindow = platform.impl.Window;
const PlatformWindowId = platform.impl.WindowId;

pub const Window = struct {
    platform_window_handle: PlatformWindow,

    pub fn deinit(self: *Window) void {
        _ = self;
        // switch (self.)
    }
};

pub const WindowId = struct {
    platform_window_id: PlatformWindowId,

    pub fn dummy() WindowId {
        return WindowId{ .platform_window_id = PlatformWindowId.dummy() };
    }
};

pub const WindowAttributes = struct {
    inner_size: ?dpi.Size = null,
    min_inner_size: ?dpi.Size = null,
    max_inner_size: ?dpi.Size = null,
    position: ?dpi.Position = null,
    resizable: bool = true,
    enabled_buttons: WindowButtons = WindowButtons{},
    title: []const u8 = "window",
    fullscreen: ?platform.Fullscreen = null,
    maximized: bool = false,
    visible: bool = true,
    transparent: bool = false,
    decorations: bool = true,
    window_icon: ?icon.Icon = null,
    preferred_theme: ?theme.Theme = null,
    resize_increments: ?dpi.Size = null,
    content_protection: bool = false,
    window_level: WindowLevel = WindowLevel.normal,
    active: bool = true,
};

pub const WindowButtons = packed struct {
    close: bool = true,
    minimize: bool = true,
    maximize: bool = true,
};

pub const WindowLevel = enum(u8) {
    always_on_bottom = 0,
    normal = 1,
    always_on_top = 2,
};
