const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const common = @import("../../core/common.zig");
const input_enums = @import("../../core/input_enums.zig");

const c = @import("c.zig");

const LPARAM = std.os.windows.LPARAM;
const BOOL = std.os.windows.BOOL;

fn monitor_enum_proc_count(
    h_monitor: c.windows.HMONITOR,
    hdc_monitor: c.windows.HDC,
    lprc_monitor: c.windows.LPRECT,
    dw_data: LPARAM,
) callconv(.C) BOOL {
    _ = lprc_monitor;
    _ = hdc_monitor;
    _ = h_monitor;
    var x = @as(usize, @intCast(dw_data));
    var count: *usize = @ptrFromInt(x);
    count.* += 1;
    return std.os.windows.TRUE;
}

pub fn getDisplayCount() usize {
    var data: usize = 0;
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitor_enum_proc_count,
        @intCast(@intFromPtr(@as(*usize, @ptrCast(&data)))),
    );
    return data;
}
