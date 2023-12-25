const std = @import("std");

const display = @import("display.zig");
const input = @import("input.zig");
const window = @import("window.zig");
const platform = @import("platform.zig");

const Self = @This();

allocator: std.mem.Allocator,

platform_application: platform.impl.Application = undefined,
input: *input.Input = undefined,

/// used when the application is detached
/// which means it runs in a separate thread
in_loop: bool = false,
loop_callback: ?*const fn (*Self) bool = null,
loop_stopped: bool = false,
window_to_be_built: ?*window.Window = null,
wait_mutex: std.Thread.Mutex = .{},
wait_condition: std.Thread.Condition = .{},

pub fn create(allocator: std.mem.Allocator) !*Self {
    var app: *Self = try allocator.create(Self);
    app.* = .{
        .allocator = allocator,
    };
    try app.init();
    return app;
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

    if (self.in_loop) {
        self.wait_mutex.lock();
        defer self.wait_mutex.unlock();
        self.window_to_be_built = wnd;

        while (self.window_to_be_built != null) {
            self.wait_condition.wait(&self.wait_mutex);
        }
    } else {
        try wnd.build();
    }

    return wnd;
}

pub fn pumpEvents(self: *Self) !void {
    try self.platform_application.pumpEvents();
}

pub fn detach(self: *Self) !void {
    var thread = try std.Thread.spawn(.{
        .allocator = self.allocator,
    }, loop, .{self});
    self.in_loop = true;
    thread.detach();
}

fn loop(self: *Self) void {
    while (!self.loop_stopped and self.in_loop) {
        if (self.window_to_be_built) |wnd| {
            {
                self.wait_mutex.lock();
                defer self.wait_mutex.unlock();
                wnd.build() catch @panic("Failed to build window");
                self.window_to_be_built = null;
            }
            self.wait_condition.signal();
        }

        self.pumpEvents() catch {
            std.log.warn("Failed to pump events", .{});
        };
        if (self.loop_callback) |cb| {
            if (cb(self)) {
                return;
            }
        }
    }
}

pub inline fn stop(self: *Self) void {
    self.loop_stopped = true;
    self.in_loop = false;
}
