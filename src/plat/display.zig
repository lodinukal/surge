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

pub fn getPrimaryDisplay() ?usize {
    return platform_display.getPrimaryDisplay();
}

pub fn getDisplayPosition(display: usize) ?common.Vec2i {
    return platform_display.getDisplayPosition(display);
}

pub fn getDisplaySize(display: usize) ?common.Vec2i {
    return platform_display.getDisplaySize(display);
}

pub fn getDisplayRefreshRate(display: usize) ?f32 {
    return platform_display.getDisplayRefreshRate(display);
}

pub fn getDisplayUsableArea(display: usize) ?common.Rect2i {
    return platform_display.getDisplayUsableArea(display);
}

pub fn getDisplayDpi(display: usize) ?usize {
    return platform_display.getDisplayDpi(display);
}

pub fn setKeepOn(enable: bool, reason: ?[]const u8) void {
    return platform_display.setKeepOn(enable, reason);
}

pub fn isKeptOn() bool {
    return platform_display.isKeptOn();
}

pub fn getDisplayFromRect(rect: common.Rect2i) ?usize {
    var nearest_area: i32 = 0;
    var pos_display: ?i32 = null;
    for (0..getDisplayCount()) |display_idx| {
        var r = common.Rect2i.zero();
        r.position = getDisplayPosition(display_idx) orelse return null;
        r.size = getDisplaySize(display_idx) orelse return null;
        var inters = r.intersection(rect);
        const area = inters.area();
        if (area > nearest_area) {
            nearest_area = area;
            pos_display = @intCast(display_idx);
        }
    }
    return if (pos_display) |d| @intCast(d) else null;
}
