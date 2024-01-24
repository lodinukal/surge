const std = @import("std");
const parser = @import("parser.zig");
const Tree = @import("tree.zig");
const lexer = @import("lexer.zig");

err_handler: ?*const fn (msg: []const u8) void = null,

pub fn err(self: *const @This(), location: ?lexer.Location, comptime msg: []const u8, args: anytype) void {
    var buf = std.mem.zeroes([1024]u8);
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const temp_allocator = fba.allocator();

    if (self.err_handler) |handler| {
        const line = if (location) |loc| loc.line else 0;
        const col = if (location) |loc| loc.column else 0;
        const fmtted = std.fmt.allocPrint(
            temp_allocator,
            "{}:{}:" ++ msg,
            .{ line, col } ++ args,
        ) catch
            unreachable;
        handler(fmtted);
    }
}
