const std = @import("std");

const platform = @import("./video/platforms/platform.zig");
const definitions = @import("./video/definitions.zig");

pub const X = enum(i32) {
    a,
    b,
    c,
    d,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    _ = alloc;

    @compileLog(@intFromEnum(X.a) | @intFromEnum(X.b));
}
