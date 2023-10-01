const std = @import("std");

const platform = @import("platform.zig").impl;

pub const Application = struct {
    allocator: std.mem.Allocator,
    windows: std.ArrayList(*Window),

    platform_application: platform.Application,

    pub fn init(allocator: std.mem.Allocator) !Application {
        var app = Application{
            .allocator = allocator,
            .windows = std.ArrayList(*Window).init(allocator),
            .platform_application = undefined,
        };

        app.platform_application = try platform.Application.init(&app);

        return app;
    }

    pub fn deinit(self: *Application) void {
        self.windows.deinit();
        self.platform_application.deinit();
    }

    pub fn createWindow(self: *Application, descriptor: WindowDescriptor) !*Window {
        const wnd = try self.allocator.create(Window);
        wnd.platform_window = try self.platform_application.createWindow(descriptor);
        try self.windows.append(wnd);
        return wnd;
    }

    pub fn pumpEvents(self: *Application) void {
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
    platform_window: platform.Window,

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
