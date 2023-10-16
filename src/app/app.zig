const std = @import("std");

pub const input = @import("input.zig");
pub const window = @import("window.zig");
pub const platform = @import("platform.zig");

pub const Application = struct {
    allocator: std.mem.Allocator,

    platform_application: platform.impl.Application = undefined,
    input: *input.Input = undefined,

    pub fn create(allocator: std.mem.Allocator) !*Application {
        var app: *Application = try allocator.create(Application);
        app.allocator = allocator;
        try app.init();
        return app;
    }

    pub fn destroy(self: *Application) void {
        self.deinit();
        self.allocator.destroy(self);
    }

    fn init(self: *Application) !void {
        try self.platform_application.init();
        self.input = try input.Input.create(self.allocator);
    }

    fn deinit(self: *Application) void {
        self.platform_application.deinit();
        self.input.destroy();
    }

    pub fn createWindow(self: *Application, descriptor: window.WindowDescriptor) !*window.Window {
        var wnd: *window.Window = try self.allocator.create(window.Window);
        wnd.application = self;
        try wnd.platform_window.init(descriptor);
        return wnd;
    }

    pub fn pumpEvents(self: *Application) !void {
        try self.platform_application.pumpEvents();
        self.input.process();
    }
};
