const std = @import("std");

const app = @import("app");
const core = @import("core");
const math = core.math;
const util = core.util;

const WindowRenderer = @import("renderer").WindowRenderer;
const Deferred = @import("renderer").Deferred;

const rl = @import("rl");
const image = @import("stb");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        // .verbose_log = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    image.setAllocator(allocator);

    var application = try app.Application.create(allocator, .{});
    defer application.destroy();

    var opened_window = try application.createWindow(.{
        .title = "helloo!",
        .size = .{ 800, 600 },
        .visible = true,
    });
    defer opened_window.destroy();

    var renderer = try WindowRenderer(Deferred).init(allocator, opened_window);
    defer renderer.deinit();
    try renderer.start();

    while (!opened_window.shouldClose()) {
        application.loop();
        try renderer.frame();
        std.time.sleep(std.time.ns_per_us * 10);
    }
}

comptime {
    _ = image;
}
