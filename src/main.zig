const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");

const interface = @import("core/interface.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var gpa_alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    var alloc = arena.allocator();

    var application = try app.Application.create(alloc);
    defer application.destroy();

    var window = try application.createWindow(.{
        .title = "!",
        .width = 800,
        .height = 600,
    });
    defer window.destroy();

    window.show(true);

    std.debug.print("{}\n", .{application.input.*});

    std.debug.print("mem: {}\n", .{arena.queryCapacity()});

    while (!window.shouldClose()) {
        try application.pumpEvents();
    }

    std.debug.print("mem: {}\n", .{arena.queryCapacity()});
}
