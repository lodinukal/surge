const std = @import("std");

const display = @import("display.zig");
const input = @import("input.zig");
const window = @import("window.zig");
const platform = @import("platform.zig");

const Self = @This();

allocator: std.mem.Allocator,
frame_allocator: ?std.mem.Allocator = null,

platform_application: platform.impl.Application = undefined,
input: *input.Input = undefined,

pub fn create(allocator: std.mem.Allocator) !*Self {
    var app: *Self = try allocator.create(Self);
    app.allocator = allocator;
    try app.init();
    return app;
}

pub fn setFrameAllocator(self: *Self, allocator: ?std.mem.Allocator) void {
    self.frame_allocator = allocator;
}

pub fn destroy(self: *Self) void {
    self.deinit();
    self.allocator.destroy(self);
}

fn init(self: *Self) !void {
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
    return wnd;
}

pub fn pumpEvents(self: *Self) !void {
    try self.platform_application.pumpEvents();
    self.input.process();
}
