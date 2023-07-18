const std = @import("std");
const c = @import("c.zig");

const common = @import("../../../core/common.zig");

const dpi = @import("../../dpi.zig");

pub const VideoMode = struct {
    size: struct { u32, u32 },
    bit_depth: u16,
    refresh_rate: u32,
    monitor: DisplayHandle,
    native_video_mode: *c.windows.DEVMODEW,

    pub fn deinit(vm: *VideoMode, allocator: std.mem.Allocator) void {
        allocator.destroy(vm.native_video_mode);
    }

    pub fn eql(a: *const VideoMode, b: *const VideoMode) bool {
        return a.size == b.size and
            a.bit_depth == b.bit_depth and
            a.refresh_rate == b.refresh_rate;
    }

    pub fn hash(vm: *const VideoMode) u64 {
        const hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(vm.size));
        hasher.update(std.mem.asBytes(vm.bit_depth));
        hasher.update(std.mem.asBytes(vm.refresh_rate));
        hasher.update(std.mem.asBytes(vm.monitor.hash()));
        return hasher.final();
    }
};

pub const DisplayHandle = struct {
    native_handle: c.windows.HMONITOR,

    pub fn init(native_handle: c.windows.HMONITOR) DisplayHandle {
        return DisplayHandle{ .native_handle = native_handle };
    }

    pub fn hash(m: *const DisplayHandle) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(m.native_handle));
        return hasher.final();
    }

    pub fn primary() DisplayHandle {
        const origin = c.windows.POINT{ .x = 0, .y = 0 };
        return DisplayHandle.init(c.windows.MonitorFromPoint(origin, c.windows.MONITOR_DEFAULTTOPRIMARY));
    }

    pub fn fromWindow(hwnd: c.windows.HWND) DisplayHandle {
        return DisplayHandle.init(c.windows.MonitorFromWindow(hwnd, c.windows.MONITOR_DEFAULTTONEAREST));
    }

    pub fn getInfo(handle: DisplayHandle) ?c.windows.MONITORINFOEXW {
        var info = std.mem.zeroes(c.windows.MONITORINFOEXW);
        info.unnamed_0.cbSize = @intCast(@sizeOf(c.windows.MONITORINFOEXW));
        if (c.windows.GetMonitorInfoW(
            handle.native_handle,
            @ptrCast(&info),
        ) == c.windows.TRUE) {
            return info;
        }
        return null;
    }

    pub inline fn getName(handle: DisplayHandle, allocator: std.mem.Allocator) !?[]u8 {
        if (handle.getInfo()) |info| {
            return try std.unicode.utf16leToUtf8Alloc(allocator, &info.szDevice);
        }
        return null;
    }

    pub inline fn getSize(handle: DisplayHandle) ?dpi.PhysicalSize {
        if (handle.getInfo()) |info| {
            const rc = info.unnamed_0.rcMonitor;
            return dpi.PhysicalSize{
                .width = @intCast(rc.right - rc.left),
                .height = @intCast(rc.bottom - rc.top),
            };
        }
        return null;
    }

    pub inline fn getRefreshRate(handle: DisplayHandle) ?u32 {
        if (handle.getInfo()) |info| {
            const device_name = info.szDevice;
            var mode = std.mem.zeroes(c.windows.DEVMODEW);
            mode.dmSize = @intCast(c.windows.sizeof(c.windows.DEVMODEW));
            if (c.windows.EnumDisplaySettingsExW(
                &device_name,
                c.windows.ENUM_CURRENT_SETTINGS,
                &mode,
                0,
            ) == c.windows.TRUE) {
                return mode.dmDisplayFrequency * 1000;
            }
        }
        return null;
    }

    pub inline fn getPosition(handle: DisplayHandle) ?dpi.PhysicalPosition {
        if (handle.getInfo()) |info| {
            const rc = info.unnamed_0.rcMonitor;
            return dpi.PhysicalPosition{
                .x = @intCast(rc.left),
                .y = @intCast(rc.top),
            };
        }
        return null;
    }

    pub inline fn getDpi(handle: DisplayHandle) ?u32 {
        if (lazyGetDpiForMonitor.get()) |getDpiForMonitor| {
            var x: u32 = 0;
            var y: u32 = 0;
            if (getDpiForMonitor(
                handle.native_handle,
                MonitorDpiType.EffectiveDpi,
                &x,
                &y,
            ) == c.windows.S_OK) {
                return x;
            }
        }
        return null;
    }

    pub inline fn getScaleFactor(handle: DisplayHandle) ?f64 {
        return dpiToScaleFactor(handle.getDpi() orelse 96);
    }
};

fn monitorCountEnumProc(
    hmonitor: c.windows.HMONITOR,
    hdc: c.windows.HDC,
    placement: [*c]c.windows.RECT,
    data: c.windows.LPARAM,
) callconv(.C) c.windows.BOOL {
    _ = hmonitor;
    _ = hdc;
    _ = placement;
    var count: *usize = @ptrFromInt(@as(usize, @intCast(data)));
    count.* += 1;
    return c.windows.TRUE;
}

const MonitorData = struct {
    data: []DisplayHandle,
    index: usize = 0,
};

fn monitorEnumProc(
    hmonitor: c.windows.HMONITOR,
    hdc: c.windows.HDC,
    placement: [*c]c.windows.RECT,
    data: c.windows.LPARAM,
) callconv(.C) c.windows.BOOL {
    _ = placement;
    _ = hdc;
    var monitor_data: *MonitorData = @ptrFromInt(@as(usize, @intCast(data)));
    monitor_data.data[monitor_data.index] = (DisplayHandle.init(hmonitor));
    monitor_data.index += 1;
    return c.windows.TRUE;
}

pub fn availableDisplays(allocator: std.mem.Allocator) ![]DisplayHandle {
    var count: usize = 0;
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitorCountEnumProc,
        @intCast(@intFromPtr(&count)),
    );
    var displays = try allocator.alloc(DisplayHandle, count);
    var monitor_data = MonitorData{ .data = displays };
    _ = c.windows.EnumDisplayMonitors(
        null,
        null,
        monitorEnumProc,
        @intCast(@intFromPtr(&monitor_data)),
    );
    return displays;
}

fn dpiToScaleFactor(indpi: u32) f64 {
    return @as(f64, @floatFromInt(indpi)) / 96.0;
}

const MonitorDpiType = enum(u8) {
    EffectiveDpi = 0,
    AngularDpi = 1,
    RawDpi = 2,
};
const GetDpiForMonitor = *fn (
    hmonitor: c.windows.HMONITOR,
    dpi_type: MonitorDpiType,
    x: *u32,
    y: *u32,
) callconv(.Win64) c.windows.HRESULT;

fn getFunction(comptime T: type, comptime lib: []const u8, comptime name: [:0]const u8) ?T {
    var module = std.DynLib.open(lib) catch return null;
    defer module.close();
    return module.lookup(T, name);
}

fn getFunctionWrap(comptime T: type, comptime lib: []const u8, comptime name: []const u8) type {
    const null_terminated = name ++ "0";
    return struct {
        cached: ?T = null,

        pub fn get(self: *@This()) ?T {
            if (self.cached == null) self.cached = getFunction(T, lib, @ptrCast(null_terminated));
            return self.cached;
        }
    };
}

var lazyGetDpiForMonitor = getFunctionWrap(GetDpiForMonitor, "shcore.dll", "GetDpiForMonitor"){};
