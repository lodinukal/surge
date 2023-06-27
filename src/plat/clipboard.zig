const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const common = @import("../core/common.zig");
const input_enums = @import("../core/input_enums.zig");

const platform_clipboard = switch (builtin.os.tag) {
    .windows => @import("windows/clipboard.zig"),
    inline else => @panic("Unsupported OS"),
};

pub fn setClipboard(text: []const u8) !void {
    return platform_clipboard.setClipboard(text);
}
pub fn getClipboard(allocator: std.mem.Allocator) ![]const u8 {
    return platform_clipboard.getClipboard(allocator);
}
pub fn hasClipboard() !bool {
    return platform_clipboard.hasClipboard();
}
