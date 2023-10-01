const std = @import("std");

const app = @import("app/app.zig");
const math = @import("core/math.zig");

const interface = @import("core/interface.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    var application = try app.Application.init(alloc);
    defer application.deinit();

    var window = try application.createWindow(.{
        .title = "window",
        .width = 800,
        .height = 600,
    });
    defer window.deinit();

    window.show(true);

    while (!window.shouldClose()) {
        application.pumpEvents();
    }
    std.debug.print("done\n", .{});
}
