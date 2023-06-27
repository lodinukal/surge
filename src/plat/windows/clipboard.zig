const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const common = @import("../core/common.zig");
const input_enums = @import("../core/input_enums.zig");

pub fn setClipboard(text: []const u8) !void {
    std.debug.print("setClipboardText: {}\n", .{text});
}
pub fn getClipboard(allocator: std.mem.Allocator) ![]const u8 {
    return try allocator.dupe(u8, "testing");
}
pub fn hasClipboard() bool {
    return true;
}
