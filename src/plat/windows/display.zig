const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const common = @import("../../core/common.zig");
const input_enums = @import("../../core/input_enums.zig");

const c = @import("c.zig");

const LPARAM = std.os.windows.LPARAM;
const BOOL = std.os.windows.BOOL;

pub fn getDisplayCount() usize {
    var data: usize = 0;
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitor_enum_proc_count,
        @intCast(@intFromPtr(&data)),
    );
    return data;
}

fn monitor_enum_proc_count(
    h_monitor: c.windows.HMONITOR,
    hdc_monitor: c.windows.HDC,
    lprc_monitor: c.windows.LPRECT,
    dw_data: LPARAM,
) callconv(.C) BOOL {
    _ = lprc_monitor;
    _ = hdc_monitor;
    _ = h_monitor;
    var count: *usize = @ptrFromInt(@as(usize, @intCast(dw_data)));
    count.* += 1;
    return std.os.windows.TRUE;
}

pub fn getPrimaryDisplay() ?usize {
    var data = EnumDisplayData{};
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitor_enum_proc_primary,
        @intCast(@intFromPtr(&data)),
    );
    return data.display;
}

fn monitor_enum_proc_primary(
    h_monitor: c.windows.HMONITOR,
    hdc_monitor: c.windows.HDC,
    lprc_monitor: c.windows.LPRECT,
    dw_data: LPARAM,
) callconv(.C) BOOL {
    _ = hdc_monitor;
    _ = h_monitor;
    var data: *EnumDisplayData = @ptrFromInt(@as(usize, @intCast(dw_data)));

    if ((lprc_monitor.*.left == 0) and (lprc_monitor.*.top == 0)) {
        data.*.display = data.*.count;
        return std.os.windows.FALSE;
    }

    data.*.count += 1;
    return std.os.windows.TRUE;
}

const EnumDisplayData = struct {
    count: usize = 0,
    display: ?usize = null,
    monitor: c.windows.HMONITOR = null,
};

pub fn getDisplayPosition(display: usize) ?common.Vec2i {
    var data = EnumDisplayPosData{ .display = display };
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitor_enum_proc_pos,
        @intCast(@intFromPtr(&data)),
    );
    return data.pos;
}

pub fn getDisplayOrigin() ?common.Vec2i {
    var data = EnumDisplayPosData{};
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitor_enum_proc_origin,
        @intCast(@intFromPtr(&data)),
    );
    return data.pos;
}

fn monitor_enum_proc_pos(
    h_monitor: c.windows.HMONITOR,
    hdc_monitor: c.windows.HDC,
    lprc_monitor: c.windows.LPRECT,
    dw_data: LPARAM,
) callconv(.C) BOOL {
    _ = hdc_monitor;
    _ = h_monitor;
    var data: *EnumDisplayPosData = @ptrFromInt(@as(usize, @intCast(dw_data)));

    if (data.*.count == data.*.display) {
        data.*.pos = common.Vec2i{ .x = lprc_monitor.*.left, .y = lprc_monitor.*.top };
        return std.os.windows.FALSE;
    }

    data.*.count += 1;
    return std.os.windows.TRUE;
}

fn monitor_enum_proc_origin(
    h_monitor: c.windows.HMONITOR,
    hdc_monitor: c.windows.HDC,
    lprc_monitor: c.windows.LPRECT,
    dw_data: LPARAM,
) callconv(.C) BOOL {
    _ = hdc_monitor;
    _ = h_monitor;
    var data: *EnumDisplayPosData = @ptrFromInt(@as(usize, @intCast(dw_data)));

    if (data.pos) |*pos| {
        pos.* = common.Vec2i{
            .x = @min(pos.x, lprc_monitor.*.left),
            .y = @min(pos.y, lprc_monitor.*.top),
        };
    } else {
        data.*.pos = common.Vec2i{ .x = lprc_monitor.*.left, .y = lprc_monitor.*.top };
    }

    return std.os.windows.TRUE;
}

const EnumDisplayPosData = struct {
    count: usize = 0,
    display: usize = 0,
    pos: ?common.Vec2i = null,
};

pub fn getDisplaySize(display: usize) ?common.Vec2i {
    var data = EnumDisplaySizeData{ .display = display };
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitor_enum_proc_size,
        @intCast(@intFromPtr(&data)),
    );
    return data.size;
}

fn monitor_enum_proc_size(
    h_monitor: c.windows.HMONITOR,
    hdc_monitor: c.windows.HDC,
    lprc_monitor: c.windows.LPRECT,
    dw_data: LPARAM,
) callconv(.C) BOOL {
    _ = hdc_monitor;
    var data: *EnumDisplaySizeData = @ptrFromInt(@as(usize, @intCast(dw_data)));

    if (data.count == data.display) {
        var mon_info: c.windows.MONITORINFO = undefined;
        mon_info.cbSize = @sizeOf(c.windows.MONITORINFO);
        _ = c.windows.GetMonitorInfoW(h_monitor, &mon_info);

        data.*.size = common.Vec2i{
            .x = lprc_monitor.*.right - lprc_monitor.*.left,
            .y = lprc_monitor.*.bottom - lprc_monitor.*.top,
        };
        return std.os.windows.FALSE;
    }

    data.*.count += 1;
    return std.os.windows.TRUE;
}

const EnumDisplaySizeData = struct {
    count: usize = 0,
    display: usize,
    size: ?common.Vec2i = null,
};

pub fn getDisplayRefreshRate(display: usize) ?f32 {
    var data = EnumDisplayRefreshData{ .display = display };
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitor_enum_proc_refresh,
        @intCast(@intFromPtr(&data)),
    );
    return data.rate;
}

fn monitor_enum_proc_refresh(
    h_monitor: c.windows.HMONITOR,
    hdc_monitor: c.windows.HDC,
    lprc_monitor: c.windows.LPRECT,
    dw_data: LPARAM,
) callconv(.C) BOOL {
    _ = lprc_monitor;
    _ = hdc_monitor;
    var data: *EnumDisplayRefreshData = @ptrFromInt(@as(usize, @intCast(dw_data)));

    if (data.count == data.display) {
        var mon_info: c.windows.MONITORINFOEXW = undefined;
        mon_info.unnamed_0.cbSize = @sizeOf(c.windows.MONITORINFOEXW);
        _ = c.windows.GetMonitorInfoW(h_monitor, @ptrCast(&mon_info));

        var dev_mode: c.windows.DEVMODEW = undefined;
        dev_mode.dmSize = @sizeOf(c.windows.DEVMODEW);
        dev_mode.dmDriverExtra = 0;
        _ = c.windows.EnumDisplaySettingsW(
            &mon_info.szDevice,
            c.windows.ENUM_CURRENT_SETTINGS,
            &dev_mode,
        );

        data.rate = @as(f32, @floatFromInt(dev_mode.dmDisplayFrequency));
        return std.os.windows.FALSE;
    }

    data.*.count += 1;
    return std.os.windows.TRUE;
}

const EnumDisplayRefreshData = struct {
    count: usize = 0,
    display: usize,
    rate: ?f32 = null,
};

pub fn getDisplayUsableArea(display: usize) ?common.Rect2i {
    var data = EnumDisplayRectData{ .display = display };
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitor_enum_proc_area,
        @intCast(@intFromPtr(&data)),
    );
    return data.rect;
}

fn monitor_enum_proc_area(
    h_monitor: c.windows.HMONITOR,
    hdc_monitor: c.windows.HDC,
    lprc_monitor: c.windows.LPRECT,
    dw_data: LPARAM,
) callconv(.C) BOOL {
    _ = lprc_monitor;
    _ = hdc_monitor;
    var data: *EnumDisplayRectData = @ptrFromInt(@as(usize, @intCast(dw_data)));

    if (data.count == data.display) {
        var mon_info: c.windows.MONITORINFO = undefined;
        mon_info.cbSize = @sizeOf(c.windows.MONITORINFO);
        _ = c.windows.GetMonitorInfoW(h_monitor, &mon_info);

        data.*.rect = common.Rect2i.from_min_max(
            common.Vec2i{ .x = mon_info.rcWork.left, .y = mon_info.rcWork.top },
            common.Vec2i{ .x = mon_info.rcWork.right, .y = mon_info.rcWork.bottom },
        );
        return std.os.windows.FALSE;
    }

    data.*.count += 1;
    return std.os.windows.TRUE;
}

const EnumDisplayRectData = struct {
    count: usize = 0,
    display: usize,
    rect: ?common.Rect2i = null,
};

pub fn getDisplayDpi(display: usize) ?usize {
    var data = EnumDisplayDpiData{ .display = display };
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitor_enum_proc_dpi,
        @intCast(@intFromPtr(&data)),
    );
    return data.dpi;
}

fn monitor_enum_proc_dpi(
    h_monitor: c.windows.HMONITOR,
    hdc_monitor: c.windows.HDC,
    lprc_monitor: c.windows.LPRECT,
    dw_data: LPARAM,
) callconv(.C) BOOL {
    _ = lprc_monitor;
    _ = hdc_monitor;
    var data: *EnumDisplayDpiData = @ptrFromInt(@as(usize, @intCast(dw_data)));

    if (data.count == data.display) {
        data.*.dpi = query_dpi_for_monitor(h_monitor, MonitorDpiType.default()) catch 96;
        return std.os.windows.FALSE;
    }

    data.*.count += 1;
    return std.os.windows.TRUE;
}

var shcore: ?std.DynLib = null;
const GetDpiForMonitorType = (fn (
    monitor: c.windows.HMONITOR,
    dpi_type: MonitorDpiType,
    dpi_x: [*]c.windows.UINT,
    dpi_y: [*]c.windows.UINT,
) callconv(.C) c.windows.HRESULT);
var get_dpi_for_monitor: ?*GetDpiForMonitorType = null;
var overall_x_dpi: u32 = 0;
var overall_y_dpi: u32 = 0;
fn query_dpi_for_monitor(hmon: c.windows.HMONITOR, dpi_type: MonitorDpiType) !usize {
    var dpi_x: u32 = 96;
    var dpi_y: u32 = 96;

    if (shcore == null) {
        shcore = try std.DynLib.open("shcore.dll");
        if (shcore) |*lib| {
            get_dpi_for_monitor = lib.lookup(*GetDpiForMonitorType, "GetDpiForMonitor");
        }

        if (get_dpi_for_monitor == null or shcore == null) {
            if (shcore) |*lib| {
                lib.close();
            }
        }
    }

    var x: c.windows.UINT = 0;
    var y: c.windows.UINT = 0;

    if (hmon) |mon| if (get_dpi_for_monitor) |gdpi| {
        const hr = gdpi(mon, dpi_type, @ptrCast(&x), @ptrCast(&y));
        if (hr >= 0) {
            dpi_x = @intCast(x);
            dpi_y = @intCast(y);
        }
    } else {
        if (overall_x_dpi <= 0 or overall_y_dpi <= 0) {
            if (c.windows.GetDC(null)) |dc| {
                overall_x_dpi = @intCast(c.windows.GetDeviceCaps(dc, c.windows.LOGPIXELSX));
                overall_y_dpi = @intCast(c.windows.GetDeviceCaps(dc, c.windows.LOGPIXELSY));
                _ = c.windows.ReleaseDC(null, dc);
            }
        }
        if (overall_x_dpi > 0 and overall_y_dpi > 0) {
            dpi_x = overall_x_dpi;
            dpi_y = overall_y_dpi;
        }
    };

    return @divTrunc(dpi_x + dpi_y, 2);
}

const MonitorDpiType = enum(u8) {
    effective_dpi = 0,
    angular_dpi = 1,
    raw_dpi = 2,

    pub inline fn default() @This() {
        return .effective_dpi;
    }
};

const EnumDisplayDpiData = struct {
    count: usize = 0,
    display: usize,
    dpi: ?usize = null,
};

var is_kept_on: bool = false;
var power_request: c.windows.HANDLE = null;
pub fn setKeepOn(enable: bool, reason: ?[]const u8) void {
    if (enable == is_kept_on) return;

    if (enable) {
        const reason_16 = std.unicode.utf8ToUtf16LeWithNull(std.heap.raw_c_allocator, reason.?);
        defer std.heap.raw_c_allocator.free(reason_16);

        const context = c.windows.REASON_CONTEXT{};
        context.Version = c.windows.DIAGNOSTIC_REASON_VERSION;
        context.Reason = c.windows.POWER_REQUEST_CONTEXT_SIMPLE_STRING;
        context.Reason.SimpleReasonString = reason_16.ptr;
        power_request = c.windows.PowerCreateRequest(&context);
        if (power_request == c.windows.INVALID_HANDLE_VALUE) {
            @panic("PowerCreateRequest failed");
        }
        if (c.windows.PowerSetRequest(
            power_request,
            c.windows.PowerRequestSystemRequired,
        ) == 0) {
            @panic("PowerSetRequest system override failed");
        }
        if (c.windows.PowerSetRequest(
            power_request,
            c.windows.PowerRequestDisplayRequired,
        ) == 0) {
            @panic("PowerSetRequest display override failed");
        }
    } else {
        c.windows.PowerClearRequest(power_request, c.windows.PowerRequestSystemRequired);
        c.windows.PowerClearRequest(power_request, c.windows.PowerRequestDisplayRequired);
        c.windows.CloseHandle(power_request);
        power_request = null;
    }

    is_kept_on = enable;
}

pub fn isKeptOn() bool {
    return is_kept_on;
}
