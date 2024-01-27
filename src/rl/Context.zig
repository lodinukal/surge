const std = @import("std");
const parser = @import("parser.zig");
const Tree = @import("Tree.zig");
const lexer = @import("lexer.zig");

const util = @import("core").util;

allocator: std.mem.Allocator,
file_provider: util.FileProvider,
err_handler: ?*const fn (msg: []const u8) void = null,
custom_keywords: ?[]const []const u8 = null,
custom_builtin_types: ?[]const Tree.BuiltinType = null,

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
