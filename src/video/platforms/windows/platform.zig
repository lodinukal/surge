const std = @import("std");
const win32 = @import("win32");

const main = @import("../../main.zig");
const platform = @import("../platform.zig");
const definitions = @import("../../definitions.zig");

const WindowsWindow = struct {
    handle: win32.foundation.HWND,
    big_icon: win32.ui.windows_and_messaging.HICON,
    small_icon: win32.ui.windows_and_messaging.HICON,

    cursor_tracked: bool,
    frame_action: bool,
    iconified: bool,
    maximised: bool,
    transparent: bool,
    scale_to_monitor: bool,
    keymenu: bool,

    width: i32,
    height: i32,

    last_cursor_pos_x: i32,
    last_cursor_pos_y: i32,
    high_surrogate: std.os.windows.WCHAR,
};

const WindowsState = struct {
    instance: win32.foundation.HINSTANCE,
    helper_window_handle: win32.foundation.HWND,
    helper_window_class: u16,
    main_window_class: u16,
    device_notification_handle: win32.foundation.HANDLE,
    acquired_monitor_count: u32,
    clipboard_string: []u8,
    keycodes: [512]u8,
    scancodes: [@intFromEnum(definitions.Key.last) + 1]u8,
    keynames: [@intFromEnum(definitions.Key.last) + 1][5]u8,
    restore_cursor_pos_x: f64,
    restore_cursor_pos_y: f64,
    disabled_cursor_window: *void,
    captured_cursor_window: *void,
    raw_input: []win32.ui.input.RAWINPUT,
    dinput8: struct {
        api: win32.devices.human_interface_device.IDirectInput8W,
    },
    ntdll: struct {
        instance: win32.foundation.HINSTANCE,
        RtlGetVersion: fn (
            *win32.system.system_information.OSVERSIONINFOEXW,
            std.os.windows.ULONG,
            std.os.windows.ULONGLONG,
        ) win32.foundation.NTSTATUS,
    },
};

const WindowsMonitor = struct {
    handle: win32.graphics.gdi.HMONITOR,
    adapter_name: [32]std.os.windows.WCHAR,
    adapter_name_len: u32,
    display_name: [32]std.os.windows.WCHAR,
    display_name_len: u32,
    public_adapter_name: [32]u8,
    public_adapter_name_len: u32,
    public_display_name: [32]u8,
    public_display_name_len: u32,
    modes_pruned: bool,
    mode_changed: bool,
};

const WindowsCursor = struct {
    handle: win32.ui.windows_and_messaging.HCURSOR,
};

const WindowsJoyobject = struct {
    offset: i32,
    type: i32,
};

const WindowsJoystick = struct {
    objects: []WindowsJoyobject,
    device: *win32.devices.human_interface_device.IDirectInputDevice8W,
    index: std.os.windows.DWORD,
    guid: win32.zig.Guid,
};

pub fn detectJoystickConnection() void {}

pub fn detectJoystickDisonnection() void {}

const WindowsTimer = struct {
    frequency: u64,

    pub fn init() void {
        win32.system.performance.QueryPerformanceFrequency(
            @ptrCast(&platform.lib.timer.platform.frequency),
        );
    }

    pub fn getTimerValue() u64 {
        var value: u64 = undefined;
        win32.system.performance.QueryPerformanceCounter(@ptrCast(&value));
        return value;
    }

    pub fn getTimerFrequency() u64 {
        return platform.lib.timer.platform.frequency;
    }
};

pub const PlatformState = WindowsState;
pub const PlatformWindow = WindowsWindow;
pub const PlatformMonitor = WindowsMonitor;
pub const PlatformCursor = WindowsCursor;
pub const PlatformJoystick = WindowsJoystick;
pub const PlatformJoystickState = void;
pub const PlatformTimer = WindowsTimer;
