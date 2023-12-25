const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");

const RenderContext = @import("RenderContext.zig");

const image = @import("image.zig");

const WindowInfo = struct {
    window: *app.Window,

    render_ctx: RenderContext = .{},
    resized: ?[2]u32 = null,

    pub fn init(self: *WindowInfo, allocator: std.mem.Allocator) !void {
        try self.render_ctx.load(allocator, self.window);
    }

    pub fn deinit(self: *WindowInfo) void {
        self.render_ctx.deinit();
    }
};

var current_window_info: ?WindowInfo = null;
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    image.setAllocator(allocator);

    var application = try app.Application.create(allocator);
    defer application.destroy();

    try application.detach();

    var opened_window = try application.createWindow(.{
        .title = "helloo!",
        .size = .{ 800, 800 },
        .visible = true,
    });
    defer opened_window.destroy();

    application.loop_callback = loop;
    application.input.frame_update_callback = frame;
    application.input.window_resized_callback = resized;

    current_window_info = WindowInfo{
        .window = opened_window,
    };
    opened_window.storeContext(WindowInfo, &current_window_info.?);
    try current_window_info.?.init(allocator);
    defer current_window_info.?.deinit();

    while (!opened_window.shouldClose()) {
        std.time.sleep(std.time.ns_per_s);
    }
}

fn loop(passed_application: *app.Application) bool {
    _ = passed_application;

    if (current_window_info) |wi| {
        frame(wi.window);
        return wi.window.shouldClose();
    }

    return true;
}

fn frame(passed_window: *app.Window) void {
    var window = passed_window.getContext(WindowInfo) orelse return;

    var render_ctx: *RenderContext = @alignCast(@ptrCast(&window.render_ctx));
    if (!render_ctx.ready) return;

    if (window.resized) |size| {
        render_ctx.resize(size) catch {};
    }

    render_ctx.draw() catch {};
    render_ctx.present() catch {};
}

fn resized(passed_window: *app.Window, size: [2]u32) void {
    var window = passed_window.getContext(WindowInfo) orelse return;
    window.resized = size;
}
