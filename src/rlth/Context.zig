const std = @import("std");
const parser = @import("parser.zig");
const Tree = @import("tree.zig");
const lexer = @import("lexer.zig");

const util = @import("core").util;

allocator: std.mem.Allocator,
file_provider: util.FileProvider,
err_handler: ?*const fn (msg: []const u8) void = null,
pub fn err(self: *const @This(), comptime msg: []const u8, args: anytype) void {
    var buf = std.mem.zeroes([1024]u8);
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const temp_allocator = fba.allocator();

    if (self.err_handler) |handler| {
        const fmtted = std.fmt.allocPrint(
            temp_allocator,
            msg,
            args,
        ) catch
            unreachable;
        handler(fmtted);
    }
}
