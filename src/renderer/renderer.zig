const std = @import("std");

pub const Camera = @import("Camera.zig");

pub const RenderContext = @import("RenderContext.zig");
pub const Deferred = @import("Deferred.zig");

const app = @import("app");
const core = @import("core");

const Window = app.Window;
const Application = app.Application;
const WindowResizedDelegateNode = app.WindowResizedDelegate.Node;

pub fn WindowRenderer(comptime R: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        info: WindowInfo,
        resize_delegate: WindowResizedDelegateNode = .{
            .callback = onResize,
        },

        const WindowInfo = struct {
            window: *Window,
            renderer: R = .{},
            resized: ?[2]u32 = null,

            pub fn init(self: *WindowInfo, allocator: std.mem.Allocator) !void {
                try self.renderer.init(allocator, self.window);
            }

            pub fn deinit(self: *WindowInfo) void {
                self.renderer.deinit();
            }
        };

        pub fn init(allocator: std.mem.Allocator, window: *Window) !Self {
            return .{
                .allocator = allocator,
                .info = .{
                    .window = window,
                },
            };
        }

        pub fn deinit(self: *Self) void {
            self.info.deinit();
            self.resize_delegate.disconnect();
        }

        pub fn start(self: *Self) !void {
            if (self.info.window.getContext(u8) != null) {
                return error.WindowAlreadyBound;
            }
            self.info.window.application.input.window_resized.connect(
                &self.resize_delegate,
            );
            self.info.window.storeContext(WindowInfo, &self.info);
            try self.info.init(self.allocator);
        }

        pub fn frame(self: *Self) !void {
            var renderer = self.info.renderer;
            if (!renderer.ready) return;

            if (self.info.resized) |size| {
                renderer.resize(size) catch {};
            }

            renderer.frame() catch {};
            renderer.present() catch {};
        }

        fn onResize(window: *Window, new_size: [2]u32) void {
            var info: ?*WindowInfo = window.getContext(WindowInfo);
            if (info == null) return;
            info.?.resized = new_size;
        }
    };
}

test {
    _ = WindowRenderer(Deferred);
}
