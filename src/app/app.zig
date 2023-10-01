const std = @import("std");

const platform = @import("platform.zig").impl;

pub const Application = struct {
    allocator: std.mem.Allocator,
    windows: std.ArrayList(*Window),

    platform_application: platform.Application,

    fn init(allocator: std.mem.Allocator) !Application {
        return .{
            .allocator = allocator,
            .windows = std.ArrayList(*Window).init(allocator),
            .platform_application = undefined,
        };
    }

    fn build(self: *Application) !void {
        self.platform_application = try platform.Application.init(self);
    }

    pub fn create(allocator: std.mem.Allocator) !*Application {
        const app: *Application = try allocator.create(Application);
        app.* = try Application.init(allocator);
        try app.build();
        return app;
    }

    pub fn destroy(self: *Application) void {
        self.deinit();
        self.allocator.destroy(self);
    }

    fn deinit(self: *Application) void {
        self.windows.deinit();
        self.platform_application.deinit();
    }

    pub fn createWindow(self: *Application, descriptor: WindowDescriptor) !*Window {
        const wnd: *Window = try self.allocator.create(Window);
        wnd.* = .{
            .allocator = self.allocator,
            .platform_window = try self.platform_application.createWindow(descriptor),
        };
        try wnd.platform_window.build();
        // try self.windows.append(wnd);
        return wnd;
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
    allocator: std.mem.Allocator,
    platform_window: platform.Window,

    fn deinit(self: *Window) void {
        self.platform_window.deinit();
    }

    pub fn destroy(self: *Window) void {
        self.deinit();
        self.allocator.destroy(self);
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
