pub const std = @import("std");

pub const app = @import("app.zig");
pub const platform = @import("./platform.zig");

pub const WindowDescriptor = struct {
    title: []const u8,
    width: i32 = 800,
    height: i32 = 600,
    x: ?i32 = null,
    y: ?i32 = null,
    is_popup: bool = false,
    fullscreen_mode: FullscreenMode = FullscreenMode.windowed,
    borderless: bool = false,
    resizable: bool = true,
    open_minimised: bool = false,
};

pub const FullscreenMode = enum {
    windowed,
    fullscreen,
};

pub const Window = struct {
    platform_window: platform.impl.Window = undefined,
    application: *app.Application = undefined,

    pub inline fn allocator(self: *const Window) std.mem.Allocator {
        return self.application.allocator;
    }

    pub fn destroy(self: *Window) void {
        self.deinit();
        self.allocator().destroy(self);
    }

    fn deinit(self: *Window) void {
        self.platform_window.deinit();
    }

    pub fn show(self: *Window, should_show: bool) void {
        self.platform_window.show(should_show);
    }

    pub fn shouldClose(self: *const Window) bool {
        return self.platform_window.shouldClose();
    }

    pub fn setShouldClose(self: *Window, should_close: bool) void {
        self.platform_window.setShouldClose(should_close);
    }
};