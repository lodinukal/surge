const std = @import("std");

const app = @import("app/app.zig");
const math = @import("core/math.zig");

const interface = @import("core/interface.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer gpa.deinit();
    var gpa_alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    var alloc = arena.allocator();

    var application = app.Application{
        .allocator = alloc,
    };
    try application.init();
    defer application.deinit();

    var window = app.Window{};
    try application.initWindow(&window, .{
        .title = "!",
        .width = 800,
        .height = 600,
    });
    defer window.deinit();

    window.show(true);

    std.debug.print("mem: {}\n", .{arena.queryCapacity()});

    while (!window.shouldClose()) {
        try application.pumpEvents();
    }
}
