const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const common = @import("../core/common.zig");
const input_enums = @import("../core/input_enums.zig");

const platform_display = switch (builtin.os.tag) {
    .windows => @import("windows/display.zig"),
    inline else => @panic("Unsupported OS"),
};

pub fn getDisplayCount() usize {
    return platform_display.getDisplayCount();
}
