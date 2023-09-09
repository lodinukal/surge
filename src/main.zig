const std = @import("std");

const platform = @import("./video/platforms/platform.zig");
const definitions = @import("./video/definitions.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    _ = alloc;

    const p = struct {
        y: fn () void,
    };
    const n = p{ .y = x };
    n.y();
}

pub fn x() void {
    std.debug.print("{}\n", .{1});
}
