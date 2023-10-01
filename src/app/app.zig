const std = @import("std");

const platform = @import("platform.zig").impl;

pub const Application = struct {
    allocator: std.mem.Allocator,

    platform_application: platform.Application = undefined,

    pub fn init(self: *Application) !void {
        try self.platform_application.init(self);
    }

    pub fn deinit(self: *Application) void {
        self.platform_application.deinit();
    }

    pub fn initWindow(self: *Application, window: *Window, descriptor: WindowDescriptor) !void {
        try self.platform_application.initWindow(&window.platform_window, descriptor);
    }

    pub fn pumpEvents(self: *Application) !void {
        return self.platform_application.pumpEvents();
    }
};

pub const WindowDescriptor = struct {
    title: []const u8,
    width: ?i32 = 800,
    height: ?i32 = 600,
};

pub const FullscreenType = enum {
    windowed,
    borderless,
    fullscreen,
};

pub const Window = struct {
    platform_window: platform.Window = undefined,

    pub fn deinit(self: *Window) void {
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
