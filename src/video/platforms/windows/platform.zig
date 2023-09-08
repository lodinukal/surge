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
    helper_window_handle: ?win32.foundation.HWND,
    helper_window_class: u16,
    main_window_class: u16,
    device_notification_handle: win32.foundation.HANDLE,
    acquired_monitor_count: u32,
    clipboard_string: []u8,
    keycodes: [std.meta.fields(definitions.Key).len]definitions.Key = [1]definitions.Key{.unknown} ** std.meta.fields(definitions.Key).len,
    scancodes: [512]i8 = [1]i8{-1} ** 512,
    keynames: [std.meta.fields(definitions.Key).len][5]u8 = [1][5]u8{[5]u8{ 0, 0, 0, 0, 0 }} ** std.meta.fields(definitions.Key).len,
    restore_cursor_pos_x: f64,
    restore_cursor_pos_y: f64,
    disabled_cursor_window: *void,
    captured_cursor_window: *void,
    raw_input: []win32.ui.input.RAWINPUT,
    dinput8: struct {
        api: win32.devices.human_interface_device.IDirectInput8W,
    },
    ntdll: struct {
        instance: ?win32.foundation.HINSTANCE,
        RtlVerifyVersionInfo: ?fn (
            *system_information.OSVERSIONINFOEXW,
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

const library_loader = win32.system.library_loader;

pub fn loadLibraries() bool {
    platform.lib.platform_state.ntdll.instance = library_loader.LoadLibraryW(
        "ntdll.dll",
    );
    if (platform.lib.platform_state.ntdll.instance) |instance| {
        platform.lib.platform_state.ntdll.RtlVerifyVersionInfo = library_loader.GetProcAddress(
            instance,
            "RtlVerifyVersionInfo",
        ) orelse return false;
    } else {
        return false;
    }

    return true;
}

pub fn unloadLibraries() void {
    if (platform.lib.platform_state.ntdll.instance) |instance| {
        library_loader.FreeLibrary(instance);
    }
}

pub fn createKeyTables() void {
    const keycodes = platform.lib.platform_state.keycodes;
    keycodes[0x00B] = definitions.Key.@"0";
    keycodes[0x002] = definitions.Key.@"1";
    keycodes[0x003] = definitions.Key.@"2";
    keycodes[0x004] = definitions.Key.@"3";
    keycodes[0x005] = definitions.Key.@"4";
    keycodes[0x006] = definitions.Key.@"5";
    keycodes[0x007] = definitions.Key.@"6";
    keycodes[0x008] = definitions.Key.@"7";
    keycodes[0x009] = definitions.Key.@"8";
    keycodes[0x00A] = definitions.Key.@"9";
    keycodes[0x01E] = definitions.Key.a;
    keycodes[0x030] = definitions.Key.b;
    keycodes[0x02E] = definitions.Key.c;
    keycodes[0x020] = definitions.Key.d;
    keycodes[0x012] = definitions.Key.e;
    keycodes[0x021] = definitions.Key.f;
    keycodes[0x022] = definitions.Key.g;
    keycodes[0x023] = definitions.Key.h;
    keycodes[0x017] = definitions.Key.i;
    keycodes[0x024] = definitions.Key.j;
    keycodes[0x025] = definitions.Key.k;
    keycodes[0x026] = definitions.Key.l;
    keycodes[0x032] = definitions.Key.m;
    keycodes[0x031] = definitions.Key.n;
    keycodes[0x018] = definitions.Key.o;
    keycodes[0x019] = definitions.Key.p;
    keycodes[0x010] = definitions.Key.q;
    keycodes[0x013] = definitions.Key.r;
    keycodes[0x01F] = definitions.Key.s;
    keycodes[0x014] = definitions.Key.t;
    keycodes[0x016] = definitions.Key.u;
    keycodes[0x02F] = definitions.Key.v;
    keycodes[0x011] = definitions.Key.w;
    keycodes[0x02D] = definitions.Key.x;
    keycodes[0x015] = definitions.Key.y;
    keycodes[0x02C] = definitions.Key.z;

    keycodes[0x028] = definitions.Key.apostrophe;
    keycodes[0x02B] = definitions.Key.backslash;
    keycodes[0x033] = definitions.Key.comma;
    keycodes[0x00D] = definitions.Key.equal;
    keycodes[0x029] = definitions.Key.grave_accent;
    keycodes[0x01A] = definitions.Key.left_bracket;
    keycodes[0x00C] = definitions.Key.minus;
    keycodes[0x034] = definitions.Key.period;
    keycodes[0x01B] = definitions.Key.right_bracket;
    keycodes[0x027] = definitions.Key.semicolon;
    keycodes[0x035] = definitions.Key.slash;
    keycodes[0x056] = definitions.Key.world_2;

    keycodes[0x00E] = definitions.Key.backspace;
    keycodes[0x153] = definitions.Key.delete;
    keycodes[0x14F] = definitions.Key.end;
    keycodes[0x01C] = definitions.Key.enter;
    keycodes[0x001] = definitions.Key.escape;
    keycodes[0x147] = definitions.Key.home;
    keycodes[0x152] = definitions.Key.insert;
    keycodes[0x15D] = definitions.Key.menu;
    keycodes[0x151] = definitions.Key.page_down;
    keycodes[0x149] = definitions.Key.page_up;
    keycodes[0x045] = definitions.Key.pause;
    keycodes[0x039] = definitions.Key.space;
    keycodes[0x00F] = definitions.Key.tab;
    keycodes[0x03A] = definitions.Key.caps_lock;
    keycodes[0x145] = definitions.Key.num_lock;
    keycodes[0x046] = definitions.Key.scroll_lock;
    keycodes[0x03B] = definitions.Key.f1;
    keycodes[0x03C] = definitions.Key.f2;
    keycodes[0x03D] = definitions.Key.f3;
    keycodes[0x03E] = definitions.Key.f4;
    keycodes[0x03F] = definitions.Key.f5;
    keycodes[0x040] = definitions.Key.f6;
    keycodes[0x041] = definitions.Key.f7;
    keycodes[0x042] = definitions.Key.f8;
    keycodes[0x043] = definitions.Key.f9;
    keycodes[0x044] = definitions.Key.f10;
    keycodes[0x057] = definitions.Key.f11;
    keycodes[0x058] = definitions.Key.f12;
    keycodes[0x064] = definitions.Key.f13;
    keycodes[0x065] = definitions.Key.f14;
    keycodes[0x066] = definitions.Key.f15;
    keycodes[0x067] = definitions.Key.f16;
    keycodes[0x068] = definitions.Key.f17;
    keycodes[0x069] = definitions.Key.f18;
    keycodes[0x06A] = definitions.Key.f19;
    keycodes[0x06B] = definitions.Key.f20;
    keycodes[0x06C] = definitions.Key.f21;
    keycodes[0x06D] = definitions.Key.f22;
    keycodes[0x06E] = definitions.Key.f23;
    keycodes[0x076] = definitions.Key.f24;
    keycodes[0x038] = definitions.Key.left_alt;
    keycodes[0x01D] = definitions.Key.left_control;
    keycodes[0x02A] = definitions.Key.left_shift;
    keycodes[0x15B] = definitions.Key.left_super;
    keycodes[0x137] = definitions.Key.print_screen;
    keycodes[0x138] = definitions.Key.right_alt;
    keycodes[0x11D] = definitions.Key.right_control;
    keycodes[0x036] = definitions.Key.right_shift;
    keycodes[0x15C] = definitions.Key.right_super;
    keycodes[0x150] = definitions.Key.down;
    keycodes[0x14B] = definitions.Key.left;
    keycodes[0x14D] = definitions.Key.right;
    keycodes[0x148] = definitions.Key.up;

    keycodes[0x052] = definitions.Key.kp_0;
    keycodes[0x04F] = definitions.Key.kp_1;
    keycodes[0x050] = definitions.Key.kp_2;
    keycodes[0x051] = definitions.Key.kp_3;
    keycodes[0x04B] = definitions.Key.kp_4;
    keycodes[0x04C] = definitions.Key.kp_5;
    keycodes[0x04D] = definitions.Key.kp_6;
    keycodes[0x047] = definitions.Key.kp_7;
    keycodes[0x048] = definitions.Key.kp_8;
    keycodes[0x049] = definitions.Key.kp_9;
    keycodes[0x04E] = definitions.Key.kp_add;
    keycodes[0x053] = definitions.Key.kp_decimal;
    keycodes[0x135] = definitions.Key.kp_divide;
    keycodes[0x11C] = definitions.Key.kp_enter;
    keycodes[0x059] = definitions.Key.kp_equal;
    keycodes[0x037] = definitions.Key.kp_multiply;
    keycodes[0x04A] = definitions.Key.kp_subtract;

    const scancodes = platform.lib.platform_state.scancodes;
    inline for (0..512) |i| {
        if (keycodes[i] != .unknown)
            scancodes[keycodes[i]] = i;
    }
}

const wam = win32.ui.windows_and_messaging;
const system_services = win32.system.system_services;

pub fn helperWindowProc(
    hwnd: win32.foundation.HWND,
    msg: std.os.windows.UINT,
    wparam: win32.foundation.WPARAM,
    lparam: win32.foundation.LPARAM,
) callconv(.Win64) win32.foundation.LRESULT {
    blk: {
        switch (msg) {
            wam.WM_DISPLAYCHANGE => {
                pollMonitors();
            },
            wam.WM_DEVICECHANGE => {
                if (!platform.lib.joysticks_initialised) break :blk;

                const dbh: ?*system_services.DEV_BROADCAST_HDR = @ptrCast(lparam);

                if (wparam == system_services.DBT_DEVICEARRIVAL) {
                    if (dbh) |found_dbh| if (found_dbh.dbch_devicetype == system_services.DBT_DEVTYP_DEVICEINTERFACE) {
                        detectJoystickConnection();
                    };
                } else if (wparam == system_services.DBT_DEVICEREMOVECOMPLETE) {
                    if (dbh) |found_dbh| if (found_dbh.dbch_devicetype == system_services.DBT_DEVTYP_DEVICEINTERFACE) {
                        detectJoystickDisonnection();
                    };
                }
            },
        }
    }

    return wam.DefWindowProcW(
        hwnd,
        msg,
        wparam,
        lparam,
    );
}

pub fn createHelperWindow() bool {
    const wc = std.mem.zeroInit(wam.WNDCLASSEXW, .{
        .style = wam.CS_OWNDC,
        .lpfnWndProc = helperWindowProc,
        .hInstance = platform.lib.platform_state.instance,
        .lpszClassName = "EngineHelperWindow",
    });

    platform.lib.platform_state.helper_window_class = wam.RegisterClassExW(
        @ptrCast(&wc),
    );
    if (platform.lib.platform_state.helper_window_class == 0) return false;

    platform.lib.platform_state.helper_window_handle = wam.CreateWindowExW(
        wam.WS_EX_OVERLAPPEDWINDOW,
        "EngineMessageWindow",
        "EngineMessageWindow",
        wam.WS_CLIPSIBLINGS | wam.WS_CLIPSIBLINGS,
        0,
        0,
        0,
        0,
        null,
        null,
        platform.lib.platform_state.instance,
        null,
    );
    if (platform.lib.platform_state.helper_window_handle == 0) return false;

    wam.ShowWindow(platform.lib.platform_state.helper_window_handle, wam.SW_HIDE);

    {
        var dbi: system_services.DEV_BROADCAST_DEVICEINTERFACE_W = std.mem.zeroes(system_services.DEV_BROADCAST_DEVICEINTERFACE_W);
        dbi.dbcc_size = @sizeOf(system_services.DEV_BROADCAST_DEVICEINTERFACE_W);
        dbi.dbcc_devicetype = system_services.DBT_DEVTYP_DEVICEINTERFACE;
        dbi.dbcc_classguid = win32.devices.human_interface_device.GUID_DEVINTERFACE_HID;

        platform.lib.platform_state.device_notification_handle = wam.RegisterDeviceNotificationW(
            platform.lib.platform_state.helper_window_handle,
            @ptrCast(&dbi),
            system_services.DEVICE_NOTIFY_WINDOW_HANDLE,
        );
    }

    var msg: wam.MSG = undefined;
    while (wam.PeekMessageW(
        &msg,
        platform.lib.platform_state.helper_window_handle,
        0,
        0,
        wam.PM_REMOVE,
    ) == win32.zig.TRUE) {
        wam.TranslateMessage(&msg);
        wam.DispatchMessageW(&msg);
    }

    return true;
}

const system_information = win32.system.system_information;
fn isWindowsOrGreaterWin32(
    major: std.os.windows.WORD,
    minor: std.os.windows.WORD,
    sp: std.os.windows.WORD,
) bool {
    var osvi: system_information.OSVERSIONINFOEXW = std.mem.zeroes(system_information.OSVERSIONINFOEXW);
    osvi.dwOSVersionInfoSize = @sizeOf(system_information.OSVERSIONINFOEXW);
    osvi.dwMajorVersion = major;
    osvi.dwMinorVersion = minor;
    osvi.wServicePackMajor = sp;

    const mask: std.os.windows.WORD = system_information.VER_MAJORVERSION |
        system_information.VER_MINORVERSION |
        system_information.VER_SERVICEPACKMAJOR;

    var cond = system_information.VerSetConditionMask(
        0,
        system_information.VER_MAJORVERSION,
        system_information.VER_GREATER_EQUAL,
    );
    cond = system_information.VerSetConditionMask(
        cond,
        system_information.VER_MINORVERSION,
        system_information.VER_GREATER_EQUAL,
    );
    cond = system_information.VerSetConditionMask(
        cond,
        system_information.VER_SERVICEPACKMAJOR,
        system_information.VER_GREATER_EQUAL,
    );

    return platform.lib.platform_state.ntdll.RtlVerifyVersionInfo.?(
        &osvi,
        mask,
        cond,
    ) == win32.foundation.STATUS_SUCCESS;
}

fn isWindows10BuildOrGreater(build: std.os.windows.WORD) bool {
    var osvi: system_information.OSVERSIONINFOEXW = std.mem.zeroes(system_information.OSVERSIONINFOEXW);
    osvi.dwOSVersionInfoSize = @sizeOf(system_information.OSVERSIONINFOEXW);
    osvi.dwMajorVersion = 10;
    osvi.dwMinorVersion = 0;
    osvi.dwBuildNumber = build;

    const mask: std.os.windows.ULONGLONG = system_information.VER_MAJORVERSION |
        system_information.VER_MINORVERSION |
        system_information.VER_BUILDNUMBER;

    var cond = system_information.VerSetConditionMask(
        0,
        system_information.VER_MAJORVERSION,
        system_information.VER_GREATER_EQUAL,
    );
    cond = system_information.VerSetConditionMask(
        cond,
        system_information.VER_MINORVERSION,
        system_information.VER_GREATER_EQUAL,
    );
    cond = system_information.VerSetConditionMask(
        cond,
        system_information.VER_BUILDNUMBER,
        system_information.VER_GREATER_EQUAL,
    );

    return platform.lib.platform_state.ntdll.RtlVerifyVersionInfo.?(
        &osvi,
        mask,
        cond,
    ) == win32.foundation.STATUS_SUCCESS;
}

pub inline fn highByte(x: u16) u8 {
    return @as(u8, @intCast(x >> 8));
}

pub inline fn lowByte(x: u16) u8 {
    return @as(u8, @intCast(x & 0xFF));
}

inline fn isWindows10Version1607OrGreater() bool {
    return isWindows10BuildOrGreater(14393);
}

inline fn isWindows10Version1703OrGreater() bool {
    return isWindows10BuildOrGreater(15063);
}

inline fn isWindowsVistaOrGreater() bool {
    return isWindowsOrGreaterWin32(
        highByte(system_information._WIN32_WINNT_VISTA),
        lowByte(system_information._WIN32_WINNT_VISTA),
        0,
    );
}

inline fn isWindows7OrGreater() bool {
    return isWindowsOrGreaterWin32(
        highByte(system_information._WIN32_WINNT_WIN7),
        lowByte(system_information._WIN32_WINNT_WIN7),
        0,
    );
}

inline fn isWindows8OrGreater() bool {
    return isWindowsOrGreaterWin32(
        highByte(system_information._WIN32_WINNT_WIN8),
        lowByte(system_information._WIN32_WINNT_WIN8),
        0,
    );
}

inline fn isWindows8Point1OrGreater() bool {
    return isWindowsOrGreaterWin32(
        highByte(system_information._WIN32_WINNT_WINBLUE),
        lowByte(system_information._WIN32_WINNT_WINBLUE),
        0,
    );
}

const kam = win32.ui.input.keyboard_and_mouse;
pub fn updateKeyNames() void {
    const keynames = platform.lib.platform_state.keynames;
    inline for (0..std.meta.fields(definitions.Key).len) |i| {
        const key = @field(definitions.Key, i.name);
        const scancode = platform.lib.platform_state.scancodes[key];
        if (scancode == -1) continue;
        const keyname = keynames[i];

        var state: [256]u8 = undefined;
        var chars: [16:0]std.os.windows.WCHAR = undefined;

        const vk = blk: {
            const lower: i16 = @intFromEnum(definitions.Key.kp_0);
            const upper: i16 = @intFromEnum(definitions.Key.kp_9);
            const this: i16 = i.value;
            if (this >= lower and this <= upper) {
                const offset = this - lower;
                const offset_map = [_]kam.VIRTUAL_KEY{
                    kam.VK_NUMPAD0,
                    kam.VK_NUMPAD1,
                    kam.VK_NUMPAD2,
                    kam.VK_NUMPAD3,
                    kam.VK_NUMPAD4,
                    kam.VK_NUMPAD5,
                    kam.VK_NUMPAD6,
                    kam.VK_NUMPAD7,
                    kam.VK_NUMPAD8,
                    kam.VK_NUMPAD9,
                    kam.VK_DIVIDE,
                    kam.VK_MULTIPLY,
                    kam.VK_SUBTRACT,
                    kam.VK_ADD,
                };
                break :blk offset_map[offset];
            } else {
                break :blk kam.MapVirtualKeyW(scancode, wam.MAPVK_VSC_TO_VK_EX);
            }
        };

        var length = kam.ToUnicode(
            vk,
            scancode,
            &state,
            @ptrCast(&chars),
            chars.len,
            0,
        );

        if (length == -1) {
            length = kam.ToUnicode(
                vk,
                scancode,
                &state,
                @ptrCast(&chars),
                chars.len,
                0,
            );
        }

        if (length >= 1) {
            var end_index: usize = 0;
            var it = std.unicode.Utf16LeIterator.init(&chars);
            while (try it.nextCodepoint()) |codepoint| {
                if (end_index >= keyname.len) break;
                end_index += std.unicode.utf8Encode(codepoint, keyname[end_index..]) catch break;
            }
            return end_index;
        }
    }
}

pub fn init() bool {
    if (!loadLibraries()) return false;

    createKeyTables();
    updateKeyNames();

    if (isWindows10Version1703OrGreater()) {
        win32.ui.hi_dpi.SetProcessDpiAwarenessContext(
            win32.ui.hi_dpi.DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2,
        );
    } else if (isWindows8Point1OrGreater()) {
        win32.ui.hi_dpi.SetProcessDpiAwareness(
            win32.ui.hi_dpi.PROCESS_PER_MONITOR_DPI_AWARE,
        );
    } else if (isWindowsVistaOrGreater()) {
        wam.SetProcessDPIAware();
    }

    if (!createHelperWindow()) return false;

    pollMonitors();
    return true;
}

pub fn deinit() void {
    if (platform.lib.platform_state.device_notification_handle != null) {
        system_services.UnregisterDeviceNotification(
            platform.lib.platform_state.device_notification_handle,
        );
    }

    if (platform.lib.platform_state.helper_window_handle != 0) {
        wam.DestroyWindow(platform.lib.platform_state.helper_window_handle);
    }

    if (platform.lib.platform_state.helper_window_class != 0) {
        wam.UnregisterClassW(
            platform.lib.platform_state.helper_window_class,
            platform.lib.platform_state.instance,
        );
    }

    if (platform.lib.platform_state.main_window_class != 0) {
        wam.UnregisterClassW(
            platform.lib.platform_state.main_window_class,
            platform.lib.platform_state.instance,
        );
    }

    platform.lib.allocator.free(platform.lib.platform_state.clipboard_string);
    platform.lib.allocator.free(platform.lib.platform_state.raw_input);

    unloadLibraries();
}

pub fn pollMonitors() void {}
