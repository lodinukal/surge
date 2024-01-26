const std = @import("std");

pub const Camera = @import("Camera.zig");

pub const RenderContext = @import("RenderContext.zig");
pub const Deferred = @import("Deferred.zig");

const app = @import("app");
const core = @import("core");

const Window = app.Window;

pub fn WindowRenderer(comptime R: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        renderer: R = .{},
        window: *Window,

        pub fn init(allocator: std.mem.Allocator, window: *Window) !Self {
            return .{
                .allocator = allocator,
                .window = window,
            };
        }

        pub fn deinit(self: *Self) void {
            self.renderer.deinit();
        }

        pub fn start(self: *Self) !void {
            try self.renderer.init(self.allocator, self.window);
        }

        pub fn frame(self: *Self) !void {
            if (!self.renderer.ready) return;

            try self.renderer.updateSize(self.window.getSize(true));

            self.renderer.frame() catch {};
            self.renderer.present() catch {};
        }
    };
}

test {
    _ = WindowRenderer(Deferred);
}
