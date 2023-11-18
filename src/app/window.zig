pub const std = @import("std");

const math = @import("../math.zig");

const app = @import("app.zig");
pub const platform = @import("./platform.zig");

pub const NativeHandle = struct { wnd: platform.impl.NativeHandle };

pub const WindowDescriptor = struct {
    title: []const u8,
    width: i32 = 800,
    height: i32 = 600,
    x: ?i32 = null,
    y: ?i32 = null,
    is_popup: bool = false,
    visible: bool = true,
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

    pub fn build(self: *Window) !void {
        try self.platform_window.build();
    }

    pub fn getNativeHandle(self: *Window) NativeHandle {
        return self.platform_window.getNativeHandle();
    }

    pub fn getContentSize(self: *const Window) [2]i32 {
        return self.platform_window.getContentSize();
    }

    pub fn getSize(self: *const Window, use_client_area: bool) [2]i32 {
        return self.platform_window.getSize(use_client_area);
    }

    pub fn setTitle(self: *Window, title: []const u8) void {
        self.platform_window.setTitle(title);
    }

    pub fn setVisible(self: *Window, should_show: bool) void {
        self.platform_window.setVisible(should_show);
    }

    pub fn isVisible(self: *const Window) bool {
        return self.platform_window.isVisible();
    }

    pub fn shouldClose(self: *const Window) bool {
        return self.platform_window.shouldClose();
    }

    pub fn setShouldClose(self: *Window, should_close: bool) void {
        self.platform_window.setShouldClose(should_close);
    }

    pub fn isFocused(self: *const Window) bool {
        return self.platform_window.isFocused();
    }
};
