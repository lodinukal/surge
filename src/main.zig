const std = @import("std");

const app = @import("app/generic/input_device_mapper.zig");

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
}

test {
    _ = app;
}
