const std = @import("std");

const display = @import("display.zig");
const input = @import("input.zig");
const window = @import("window.zig");
const platform = @import("platform.zig");

const core = @import("core");

const Self = @This();

pub const Options = struct {};

allocator: std.mem.Allocator,

platform_application: platform.impl.Application = undefined,
input: *input.Input = undefined,

pub fn create(allocator: std.mem.Allocator, options: Options) !*Self {
    var app: *Self = try allocator.create(Self);
    app.* = .{
        .allocator = allocator,
    };
    try app.init(options);
    return app;
}

pub fn destroy(self: *Self) void {
    self.deinit();
    self.allocator.destroy(self);
}

fn init(self: *Self, options: Options) !void {
    _ = options; // autofix
    try self.platform_application.init();
    self.input = try input.Input.create(self.allocator);
}

fn deinit(self: *Self) void {
    self.platform_application.deinit();
    self.input.destroy();
}

pub fn createWindow(self: *Self, descriptor: window.WindowDescriptor) !*window.Window {
    var wnd: *window.Window = try self.allocator.create(window.Window);
    wnd.* = .{
        .application = self,
    };
    try wnd.platform_window.init(descriptor);

    try wnd.build();

    return wnd;
}

pub fn pumpEvents(self: *Self) !void {
    try self.platform_application.pumpEvents();
}

pub fn loop(self: *Self) void {
    self.pumpEvents() catch {
        std.log.warn("Failed to pump events", .{});
    };
}
