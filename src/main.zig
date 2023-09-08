const std = @import("std");

const platform = @import("./video/platforms/platform.zig");
const definitions = @import("./video/definitions.zig");

var x: [std.meta.fields(definitions.Key).len][5]u8 = [1][5]u8{[5]u8{ 0, 0, 0, 0, 0 }} ** std.meta.fields(definitions.Key).len;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    _ = alloc;

    std.debug.print("{any}\n", .{x});
}
