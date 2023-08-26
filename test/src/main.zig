const std = @import("std");

fn doSomething(comptime T: type, other: usize) usize {
    std.debug.print("isComptime: {}\n", .{@inComptime()});
    return T.number + other;
}

const X = struct {
    pub const number: usize = 42;
};

pub fn main() !void {
    var n = doSomething(X, 1);
    std.debug.print("doSomething: {}\n", .{n});
}
