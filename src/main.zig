const std = @import("std");

const platform = @import("./video/platforms/platform.zig");
const definitions = @import("./video/definitions.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    var x: []u8 = try alloc.dupe(u8, &[1]u8{@as(u8, 0)} ** 100);
    x[0] = 'h';
    x[1] = 'e';
    x[2] = 'l';
    x[3] = 'l';
    x[4] = 'o';
    x[6] = 'w';

    var s = std.mem.span(
        @as([*:0]const u8, @ptrCast(x)),
    );

    std.debug.print("s: {s}, len: {}\n", .{ s, s.len });
}
