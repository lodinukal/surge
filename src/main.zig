const std = @import("std");

const app = @import("app/app.zig");
const input = @import("app/input.zig");
const math = @import("math.zig");

const interface = @import("core/interface.zig");

pub fn focused_changed_callback(focused: bool) void {
    std.debug.print("focused: {}\n", .{focused});
}

pub fn input_began_callback(ipo: input.InputObject) void {
    // std.debug.print("input began: {}\n", .{ipo});
    if (ipo.type == .mousebutton) {
        std.debug.print("mousebutton {} down\n", .{ipo.specific_data.mousebutton});
    }
}

pub fn input_changed_callback(ipo: input.InputObject) void {
    _ = ipo;
    // std.debug.print("input changed: {}\n", .{ipo});
}

pub fn input_ended_callback(ipo: input.InputObject) void {
    // std.debug.print("input ended: {}\n", .{ipo});
    if (ipo.type == .mousebutton) {
        std.debug.print("mousebutton {} up\n", .{ipo.specific_data.mousebutton});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var gpa_alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    var alloc = arena.allocator();

    var application = try app.Application.create(alloc);
    defer application.destroy();

    application.input.focused_changed_callback = focused_changed_callback;
    application.input.input_began_callback = input_began_callback;
    application.input.input_changed_callback = input_changed_callback;
    application.input.input_ended_callback = input_ended_callback;

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
