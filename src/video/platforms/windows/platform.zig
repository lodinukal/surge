const std = @import("std");
const win32 = @import("win32");

const main = @import("../../main.zig");
const platform = @import("../platform.zig");
const definitions = @import("../../definitions.zig");

export const NvOptimusEnablement: std.os.windows.DWORD = 1;
export const AmdPowerXpressRequestHighPerformance: std.os.windows.DWORD = 1;

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

const hid = win32.devices.human_interface_device;
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
        api: ?*hid.IDirectInput8W = null,
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
    type: JoyType,
};

const JoyType = enum(i32) {
    axis = 0,
    slider = 1,
    button = 2,
    pov = 3,
};

const WindowsJoystick = struct {
    objects: []WindowsJoyobject,
    object_count: i32 = 0,
    device: ?*hid.IDirectInputDevice8W = null,
    index: std.os.windows.DWORD,
    guid: win32.zig.Guid,
};

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
        dbi.dbcc_classguid = hid.GUID_DEVINTERFACE_HID;

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

pub inline fn makeLong(low: u16, high: u16) u32 {
    return @as(u32, @intCast(low)) | (@as(u32, @intCast(high)) << 16);
}

pub inline fn isEqualGuid(a: win32.zig.Guid, b: win32.zig.Guid) bool {
    return std.mem.eql(u8, &a.Bytes, &b.Bytes);
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

pub fn connect(platform_id: std.Target.Os.Tag, platform_out: *platform.InternalPlatform) bool {
    _ = platform_id;
    const out = platform.InternalPlatform{
        .init = init,
        .deinit = deinit,
        .getCursorPos = undefined,
        .setCursorPos = undefined,
        .setCursorMode = undefined,
        .setRawMouseMotion = undefined,
        .isRawMouseMotionSupported = undefined,
        .createCursor = undefined,
        .createStandardCursor = undefined,
        .destroyCursor = undefined,
        .setCursor = undefined,
        .getScancodeName = undefined,
        .getKeyScancode = undefined,
        .setClipboardString = undefined,
        .getClipboardString = undefined,
        .initJoysticks = initJoysticks,
        .deinitJoysticks = deinitJoysticks,
        .pollJoystick = pollJoystick,
        .getMappingName = getMappingName,
        .updateGamepadGuid = updateGamepadGuid,

        .freeMonitor = undefined,
        .getMonitorPos = undefined,
        .getMonitorContentScale = undefined,
        .getMonitorWorkarea = undefined,
        .getVideoModes = undefined,
        .getVideoMode = undefined,
        .getGammaRamp = undefined,
        .setGammaRamp = undefined,

        .createWindow = undefined,
        .destroyWindow = undefined,
        .setWindowTitle = undefined,
        .setWindowIcons = undefined,
        .getWindowPos = undefined,
        .setWindowPos = undefined,
        .getWindowSize = undefined,
        .setWindowSize = undefined,
        .setWindowSizeLimits = undefined,
        .setWindowAspectRatio = undefined,
        .getFramebufferSize = undefined,
        .getWindowFrameSize = undefined,
        .getWindowContentScale = undefined,
        .iconifyWindow = undefined,
        .restoreWindow = undefined,
        .maximiseWindow = undefined,
        .showWindow = undefined,
        .hideWindow = undefined,
        .requestWindowAttention = undefined,
        .focusWindow = undefined,
        .setWindowMonitor = undefined,
        .isWindowFocused = undefined,
        .isWindowIconified = undefined,
        .isWindowVisible = undefined,
        .isWindowMaximised = undefined,
        .isWindowHovered = undefined,
        .isFramebufferTransparent = undefined,
        .getWindowOpacity = undefined,
        .setWindowResizable = undefined,
        .setWindowDecorated = undefined,
        .setWindowFloating = undefined,
        .setWindowOpacity = undefined,
        .setWindowMousePassthrough = undefined,
        .pollEvents = undefined,
        .waitEvents = undefined,
        .waitEventsTimeout = undefined,
        .postEmptyEvent = undefined,
    };
    platform_out.* = out;
    return true;
}

const DInputObjectEnum = struct {
    device: *hid.IDirectInputDevice8W,
    objects: []WindowsJoyobject,
    object_count: i32 = 0,
    axis_count: i32 = 0,
    button_count: i32 = 0,
    pov_count: i32 = 0,
    slider_count: i32 = 0,
};

const DIJOFS_X = @offsetOf(hid.DIJOYSTATE, "lX");
const DIJOFS_Y = @offsetOf(hid.DIJOYSTATE, "lY");
const DIJOFS_Z = @offsetOf(hid.DIJOYSTATE, "lZ");
const DIJOFS_RX = @offsetOf(hid.DIJOYSTATE, "lRx");
const DIJOFS_RY = @offsetOf(hid.DIJOYSTATE, "lRy");
const DIJOFS_RZ = @offsetOf(hid.DIJOYSTATE, "lRz");
fn DIJOFS_SLIDER(n: i32) u32 {
    (return @offsetOf(hid.DIJOYSTATE, "rglSlider") +
        (n) * @sizeOf(std.os.windows.LONG));
}
fn DIJOFS_POV(n: i32) u32 {
    return (@offsetOf(hid.DIJOYSTATE, "rgdwPOV") +
        (n) * @sizeOf(std.os.windows.DWORD));
}
fn DIJOFS_BUTTON(n: i32) u32 {
    return (@offsetOf(hid.DIJOYSTATE, "rgbButtons") + (n));
}

const DIDFT_OPTIONAL: u32 = 0x80000000;

const object_data_formats = [_]hid.DIOBJECTDATAFORMAT{
    .{
        .pguid = &hid.GUID_XAxis,
        .dwOfs = DIJOFS_X,
        .dwType = hid.DIDFT_AXIS | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = hid.DIDOI_ASPECTPOSITION,
    },
    .{
        .pguid = &hid.GUID_YAxis,
        .dwOfs = DIJOFS_Y,
        .dwType = hid.DIDFT_AXIS | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = hid.DIDOI_ASPECTPOSITION,
    },
    .{
        .pguid = &hid.GUID_ZAxis,
        .dwOfs = DIJOFS_Z,
        .dwType = hid.DIDFT_AXIS | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = hid.DIDOI_ASPECTPOSITION,
    },
    .{
        .pguid = &hid.GUID_RxAxis,
        .dwOfs = DIJOFS_RX,
        .dwType = hid.DIDFT_AXIS | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = hid.DIDOI_ASPECTPOSITION,
    },
    .{
        .pguid = &hid.GUID_RyAxis,
        .dwOfs = DIJOFS_RY,
        .dwType = hid.DIDFT_AXIS | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = hid.DIDOI_ASPECTPOSITION,
    },
    .{
        .pguid = &hid.GUID_RzAxis,
        .dwOfs = DIJOFS_RZ,
        .dwType = hid.DIDFT_AXIS | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = hid.DIDOI_ASPECTPOSITION,
    },
    .{
        .pguid = &hid.GUID_Slider,
        .dwOfs = DIJOFS_SLIDER(0),
        .dwType = hid.DIDFT_AXIS | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = hid.DIDOI_ASPECTPOSITION,
    },
    .{
        .pguid = &hid.GUID_Slider,
        .dwOfs = DIJOFS_SLIDER(1),
        .dwType = hid.DIDFT_AXIS | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = hid.DIDOI_ASPECTPOSITION,
    },
    .{
        .pguid = &hid.GUID_POV,
        .dwOfs = DIJOFS_POV(0),
        .dwType = hid.DIDFT_POV | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = &hid.GUID_POV,
        .dwOfs = DIJOFS_POV(1),
        .dwType = hid.DIDFT_POV | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = &hid.GUID_POV,
        .dwOfs = DIJOFS_POV(2),
        .dwType = hid.DIDFT_POV | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = &hid.GUID_POV,
        .dwOfs = DIJOFS_POV(3),
        .dwType = hid.DIDFT_POV | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(0),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(1),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(2),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(3),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(4),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(5),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(6),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(7),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(8),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(9),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(10),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(11),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(12),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(13),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(14),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(15),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(16),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(17),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(18),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(19),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(20),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(21),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(22),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(23),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(24),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(25),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(26),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(27),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(28),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(29),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(30),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
    .{
        .pguid = null,
        .dwOfs = DIJOFS_BUTTON(31),
        .dwType = hid.DIDFT_BUTTON | DIDFT_OPTIONAL | hid.DIDFT_ANYINSTANCE,
        .dwFlags = 0,
    },
};

const dataFormat = hid.DIDATAFORMAT{
    .dwSize = @sizeOf(hid.DIDATAFORMAT),
    .dwObjSize = @sizeOf(hid.DIOBJECTDATAFORMAT),
    .dwFlags = hid.DIDFT_ABSAXIS,
    .dwDataSize = @sizeOf(hid.DIJOYSTATE),
    .dwNumObjs = object_data_formats.len,
    .rgodf = @ptrCast(&object_data_formats),
};

const xbc = win32.ui.input.xbox_controller;
fn getDeviceDescription(xic: *const xbc.XINPUT_CAPABILITIES) []const u8 {
    return switch (xic.SubType) {
        xbc.XINPUT_DEVSUBTYPE_WHEEL => "XInput Wheel",
        xbc.XINPUT_DEVSUBTYPE_ARCADE_STICK => "XInput Arcade Stick",
        xbc.XINPUT_DEVSUBTYPE_FLIGHT_STICK => "XInput Flight Stick",
        xbc.XINPUT_DEVSUBTYPE_DANCE_PAD => "XInput Dance Pad",
        xbc.XINPUT_DEVSUBTYPE_GUITAR => "XInput Guitar",
        xbc.XINPUT_DEVSUBTYPE_GUITAR_ALTERNATE => "XInput Alternate Guitar",
        xbc.XINPUT_DEVSUBTYPE_DRUM_KIT => "XInput Drum Kit",
        xbc.XINPUT_DEVSUBTYPE_GUITAR_BASS => "XInput Bass Guitar",
        xbc.XINPUT_DEVSUBTYPE_ARCADE_PAD => "XInput Arcade Pad",
        xbc.XINPUT_DEVSUBTYPE_GAMEPAD => if ((xic.Flags & xbc.XINPUT_CAPS_WIRELESS) != 0)
            "Wireless Xbox Controller"
        else
            "Xbox Controller",
        xbc.XINPUT_DEVSUBTYPE_UNKNOWN => "XInput Unknown",
        else => "Unknown XInput Device",
    };
}

fn orderJoystickObjects(first: *const void, second: *const void) std.math.Order {
    const first_object: *const WindowsJoyobject = @ptrCast(first);
    const second_object: *const WindowsJoyobject = @ptrCast(second);
    if (first_object.type != second_object.type) return std.math.order(
        @as(usize, @intFromEnum(first_object.type)),
        @as(usize, @intFromEnum(second_object.type)),
    );

    return std.math.order(
        first_object.offset,
        second_object.offset,
    );
}

const input = win32.ui.input;
fn supportsXInput(guid: *const win32.zig.Guid) bool {
    var count: u32 = 0;
    if (input.GetRawInputDeviceList(
        null,
        &count,
        @sizeOf(input.RAWINPUTDEVICELIST),
    ) != 0) return false;

    var ridl: []input.RAWINPUTDEVICELIST = platform.lib.allocator.alloc(
        input.RAWINPUTDEVICELIST,
        count,
    ) catch return false;
    defer platform.lib.allocator.free(ridl);

    const wrapped_err = blk: {
        var x: u32 = 0;
        x -%= 1;
        break :blk x;
    };
    if (input.GetRawInputDeviceList(
        @ptrCast(ridl),
        &count,
        @sizeOf(input.RAWINPUTDEVICELIST),
    ) == wrapped_err) return false;

    var result = false;
    for (ridl) |ridli| {
        if (ridli.dwType != input.RIM_TYPEHID) continue;
        var rdi = std.mem.zeroes(input.RID_DEVICE_INFO);
        rdi.cbSize = @sizeOf(input.RID_DEVICE_INFO);
        var size = @sizeOf(input.RID_DEVICE_INFO);

        if (input.GetRawInputDeviceInfoA(
            ridli.hDevice,
            input.RIDI_DEVICEINFO,
            @ptrCast(&rdi),
            &size,
        ) == wrapped_err) continue;

        if (makeLong(
            rdi.Anonymous.hid.dwVendorId,
            rdi.Anonymous.hid.dwProductId,
        ) != guid.Ints.a) continue;

        var name = [1]u8{0} ** 256;
        size = name.len;

        if (input.GetRawInputDeviceInfoA(
            ridli.hDevice,
            input.RIDI_DEVICENAME,
            @ptrCast(&rdi),
            &size,
        ) == wrapped_err) break;

        name[name.len - 1] = 0;
        if (std.mem.indexOf(u8, &name, "IG_")) {
            result = true;
            break;
        }
    }

    return result;
}

fn closeJoystick(joy: *platform.InternalJoystick) void {
    platform.inputJoystickConnection(joy, false);

    if (joy.platform.device) |device| {
        device.IDirectInputDevice8W_Unacquire();
        device.IUnknown_Release();
    }

    platform.lib.allocator.free(joy.platform.objects);
    platform.freeJoystick(joy);
}

fn MAKEDIPROP(x: anytype) win32.zig.Guid {
    @setRuntimeSafety(false);
    defer @setRuntimeSafety(true);

    var result = win32.zig.Guid{};
    (&result).* = (@as(*const win32.zig.Guid, @ptrCast(&x))).*;
    return result;
}

const DIPROP_BUFFERSIZE = MAKEDIPROP(1);
const DIPROP_AXISMODE = MAKEDIPROP(2);

const DIPROP_GRANULARITY = MAKEDIPROP(3);
const DIPROP_RANGE = MAKEDIPROP(4);
const DIPROP_DEADZONE = MAKEDIPROP(5);
const DIPROP_SATURATION = MAKEDIPROP(6);
const DIPROP_FFGAIN = MAKEDIPROP(7);
const DIPROP_FFLOAD = MAKEDIPROP(8);
const DIPROP_AUTOCENTER = MAKEDIPROP(9);

fn deviceObjectCallback(
    doi: *const hid.DIDEVICEOBJECTINSTANCEW,
    user: *void,
) callconv(.Win64) std.os.windows.BOOL {
    const data: *DInputObjectEnum = @ptrCast(user);
    const object: *WindowsJoyobject = data.objects[data.objects.len - 1];

    if ((lowByte(doi.dwType) & hid.DIDFT_AXIS) != 0) {
        if (isEqualGuid(hid.GUID_Slider, doi.guidType)) {
            object.offset = DIJOFS_SLIDER(data.slider_count);
        } else if (isEqualGuid(hid.GUID_XAxis, doi.guidType)) {
            object.offset = DIJOFS_X;
        } else if (isEqualGuid(hid.GUID_YAxis, doi.guidType)) {
            object.offset = DIJOFS_Y;
        } else if (isEqualGuid(hid.GUID_ZAxis, doi.guidType)) {
            object.offset = DIJOFS_Z;
        } else if (isEqualGuid(hid.GUID_RxAxis, doi.guidType)) {
            object.offset = DIJOFS_RX;
        } else if (isEqualGuid(hid.GUID_RyAxis, doi.guidType)) {
            object.offset = DIJOFS_RY;
        } else if (isEqualGuid(hid.GUID_RzAxis, doi.guidType)) {
            object.offset = DIJOFS_RZ;
        } else {
            return hid.DIENUM_CONTINUE;
        }

        var dipr = std.mem.zeroes(hid.DIPROPRANGE);
        dipr.diph.dwSize = @sizeOf(hid.DIPROPRANGE);
        dipr.diph.dwHeaderSize = @sizeOf(hid.DIPROPHEADER);
        dipr.diph.dwHow = hid.DIPH_BYID;
        dipr.diph.dwObj = doi.dwType;
        dipr.lMin = -32768;
        dipr.lMax = 32767;

        if (win32.zig.FAILED(data.device.IDirectInputDevice8W_SetProperty(&DIPROP_RANGE, &dipr.diph))) {
            return hid.DIENUM_CONTINUE;
        }

        if (isEqualGuid(hid.GUID_Slider, doi.guidType)) {
            object.type = JoyType.slider;
            data.slider_count += 1;
        } else {
            object.type = JoyType.axis;
            data.axis_count += 1;
        }
    } else if ((lowByte(doi.dwType) & hid.DIDFT_POV) != 0) {
        object.offset = DIJOFS_POV(data.pov_count);
        object.type = JoyType.pov;
        data.pov_count += 1;
    } else if ((lowByte(doi.dwType) & hid.DIDFT_BUTTON) != 0) {
        object.offset = DIJOFS_BUTTON(data.button_count);
        object.type = JoyType.button;
        data.button_count += 1;
    }

    data.object_count += 1;
    return hid.DIENUM_CONTINUE;
}

fn deviceCallback(di: *const hid.DIDEVICEINSTANCEW, user: *void) std.os.windows.BOOL {
    _ = user;
    for (platform.lib.joysticks) |joy| {
        if (joy.connected) {
            if (isEqualGuid(joy.platform.guid, di.guidInstance)) {
                return hid.DIENUM_CONTINUE;
            }
        }
    }

    if (supportsXInput(di.guidProduct)) {
        return hid.DIENUM_CONTINUE;
    }

    var device: *hid.IDirectInputDevice8W = blk: {
        var device_opt: ?*hid.IDirectInputDevice8W = null;
        if (win32.zig.FAILED(platform.lib.platform_state.dinput8.api.?.IDirectInput8W_CreateDevice(
            &di.guidInstance,
            &device_opt,
            null,
        ))) {
            main.setErrorString("Failed to create joystick device");
            return hid.DIENUM_CONTINUE;
        }
        break :blk device_opt orelse return hid.DIENUM_CONTINUE;
    };

    if (win32.zig.FAILED(device.IDirectInputDevice8W_SetDataFormat(&dataFormat))) {
        device.IUnknown_Release();
        main.setErrorString("Failed to set data format for joystick");
        return hid.DIENUM_CONTINUE;
    }

    var dc = std.mem.zeroes(hid.DIDEVCAPS);
    dc.dwSize = @sizeOf(hid.DIDEVCAPS);

    if (win32.zig.FAILED(device.IDirectInputDevice8W_GetCapabilities(&dc))) {
        device.IUnknown_Release();
        main.setErrorString("Failed to get capabilities for joystick");
        return hid.DIENUM_CONTINUE;
    }

    var dipd = std.mem.zeroes(hid.DIPROPDWORD);
    dipd.diph.dwSize = @sizeOf(hid.DIPROPDWORD);
    dipd.diph.dwHeaderSize = @sizeOf(hid.DIPROPHEADER);
    dipd.diph.dwHow = hid.DIPH_DEVICE;
    dipd.dwData = hid.DIPROPAXISMODE_ABS;

    if (win32.zig.FAILED(device.IDirectInputDevice8W_SetProperty(&DIPROP_AXISMODE, &dipd.diph))) {
        device.IUnknown_Release();
        main.setErrorString("Failed to set axis mode for joystick");
        return hid.DIENUM_CONTINUE;
    }

    var data = DInputObjectEnum{
        .device = device,
        .objects = platform.lib.allocator.alloc(
            WindowsJoyobject,
            dc.dwAxes + dc.dwButtons + dc.dwPOVs,
        ),
    };

    if (win32.zig.FAILED(device.IDirectInputDevice8W_EnumObjects(
        &deviceObjectCallback,
        @ptrCast(&data),
        hid.DIDFT_AXIS | hid.DIDFT_BUTTON | hid.DIDFT_POV,
    ))) {
        device.IUnknown_Release();
        main.setErrorString("Failed to enumerate objects for joystick");
        platform.lib.allocator.free(data.objects);
        return hid.DIENUM_CONTINUE;
    }

    std.sort.pdq(
        WindowsJoyobject,
        data.objects,
        {},
        struct {
            fn less(_: void, lhs: WindowsJoyobject, rhs: WindowsJoyobject) bool {
                return orderJoystickObjects(
                    @ptrCast(&lhs),
                    @ptrCast(&rhs),
                ) == std.math.Order.lt;
            }
        }.less,
    );

    var name = [1]u8{0} ** 256;
    var end_index: usize = 0;
    var it = std.unicode.Utf16LeIterator.init(&di.tszInstanceName);
    if (blk: {
        while (it.nextCodepoint() catch break :blk false) |codepoint| {
            if (end_index >= name.len) break true;
            end_index += std.unicode.utf8Encode(codepoint, name[end_index..]) catch break true;
        }
    } == false) {
        device.IUnknown_Release();
        main.setErrorString("Failed to enumerate objects for joystick");
        platform.lib.allocator.free(data.objects);
        return hid.DIENUM_STOP;
    }

    const guid: [32]u8 = blk: {
        var result: [32]u8 = [1]u8{0} ** 32;
        if (std.mem.eql(u8, di.guidProduct.Ints.d[2..], "PIDVID")) {
            std.fmt.bufPrint(&result, "03000000{x:0>2}{x:0>2}0000{x:0>2}{x:0>2}0000000000000000", .{
                @as(u8, @truncate(di.guidProduct.Ints.a)),
                @as(u8, @truncate(di.guidProduct.Ints.a >> 8)),
                @as(u8, @truncate(di.guidProduct.Ints.a >> 16)),
                @as(u8, @truncate(di.guidProduct.Ints.a >> 24)),
            }) catch {};
        } else {
            std.fmt.bufPrint(&result, "05000000{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}{x:0>2}00", .{
                name[0],
                name[1],
                name[2],
                name[3],
                name[4],
                name[5],
                name[6],
                name[7],
                name[8],
                name[9],
                name[10],
            }) catch {};
        }
        break :blk result;
    };

    const joystick = platform.allocateJoystick(
        name,
        guid,
        data.axis_count + data.slider_count,
        data.button_count,
        data.pov_count,
    ) catch {
        device.IUnknown_Release();
        platform.lib.allocator.free(data.objects);
        return hid.DIENUM_STOP;
    };

    joystick.platform.device = device;
    joystick.platform.guid = di.guidInstance;
    joystick.platform.objects = data.objects;
    joystick.platform.object_count = data.object_count;

    platform.inputJoystickConnection(joystick, true);
    return hid.DIENUM_CONTINUE;
}

fn detectJoystickConnection() void {
    {
        for (0..xbc.XUSER_MAX_COUNT) |index| {
            const joystick_index: usize = blk: {
                for (platform.lib.joysticks, 0..) |joy, joy_index| {
                    if (joy.connected and
                        joy.platform.device == null and
                        joy.platform.index == index)
                    {
                        break :blk joy_index;
                    }
                    break :blk null;
                }
            } orelse continue;
            _ = joystick_index;

            var xic = std.mem.zeroes(xbc.XINPUT_CAPABILITIES);
            if (blk: {
                break :blk @as(win32.foundation.WIN32_ERROR, @enumFromInt(
                    xbc.XInputGetCapabilities(
                        index,
                        0,
                        &xic,
                    ),
                ));
            } != win32.foundation.ERROR_SUCCESS) {
                continue;
            }

            var guid: [32]u8 = [1]u8{0} ** 32;
            std.fmt.bufPrint(
                &guid,
                "78696e707574{x:0>2}000000000000000000",
                .{xic.SubType & 0xff},
            ) catch continue;

            var joy = platform.allocateJoystick(
                getDeviceDescription(&xic),
                guid,
                6,
                10,
                1,
            ) catch continue;

            joy.platform.index = index;
            platform.inputJoystickConnection(joy, true);
        }

        if (platform.lib.platform_state.dinput8.api) |api| {
            if (win32.zig.FAILED(api.IDirectInput8W_EnumDevices(
                hid.DI8DEVCLASS_GAMECTRL,
                &deviceCallback,
                null,
                hid.DIEDFL_ALLDEVICES,
            ))) {
                main.setErrorString("Failed to enumerate joysticks");
                return;
            }
        }
    }
}

fn detectJoystickDisonnection() void {
    for (platform.lib.joysticks) |joy| {
        if (joy.connected) {
            _ = pollJoystick(&joy, .presence);
        }
    }
}

fn initJoysticks() bool {
    if (win32.zig.FAILED(hid.DirectInput8Create(
        platform.lib.platform_state.instance,
        hid.DIRECTINPUT_VERSION,
        &hid.IID_IDirectInput8W,
        &platform.lib.platform_state.dinput8.api,
        null,
    ))) {
        main.setErrorString("Failed to create DirectInput8 API");
        return false;
    }

    detectJoystickConnection();
    return true;
}

fn deinitJoysticks() void {
    for (&platform.lib.joysticks) |*joy| {
        closeJoystick(joy);
    }

    if (platform.lib.platform_state.dinput8.api) |api| {
        api.IUnknown_Release();
    }
}

fn pollJoystick(joy: *platform.InternalJoystick, mode: platform.Poll) bool {
    if (joy.platform.device) |device| {
        device.IDirectInputDevice8W_Poll();
        var state = std.mem.zeroes(hid.DIJOYSTATE);
        var result = device.IDirectInputDevice8W_GetDeviceState(
            @sizeOf(hid.DIJOYSTATE),
            @ptrCast(&state),
        );
        if (result == hid.DIERR_NOTACQUIRED or result == hid.DIERR_INPUTLOST) {
            device.IDirectInputDevice8W_Acquire();
            device.IDirectInputDevice8W_Poll();
            result = device.IDirectInputDevice8W_GetDeviceState(
                @sizeOf(hid.DIJOYSTATE),
                @ptrCast(&state),
            );
        }

        if (win32.zig.FAILED(result)) {
            closeJoystick(joy);
            return false;
        }

        if (mode == .presence) {
            return true;
        }

        var axis_index: i32 = 0;
        var button_index: i32 = 0;
        var pov_index: i32 = 0;
        for (0..joy.platform.object_count) |index| {
            const obj = joy.platform.objects[index];
            var data: *const u8 = @as(*const u8, &state)[obj.offset];
            switch (obj.type) {
                .axis, .slider => {
                    const data_converted: *u64 = @ptrCast(data);
                    const value: f32 = (@as(f32, @ptrFromInt(data_converted.*)) + 0.5) / 32767.5;
                    platform.inputJoystickAxis(joy, axis_index, value);
                    axis_index += 1;
                },
                .button => {
                    const data_converted: *u8 = @ptrCast(data);
                    const value = (data_converted.* & 0x80) != 0;
                    platform.inputJoystickButton(
                        joy,
                        button_index,
                        value,
                    );
                    button_index += 1;
                },
                .pov => {
                    const states = [9]definitions.Hat{
                        .up,
                        .right_up,
                        .right,
                        .right_down,
                        .down,
                        .left_down,
                        .left,
                        .left_up,
                        .center,
                    };

                    const data_converted: *u32 = @ptrCast(data);
                    const state_index = @divTrunc(data_converted.*, 45 * hid.DI_DEGREES);
                    if (state_index < 0 or state_index > 8) {
                        state_index = 8;
                    }
                    platform.inputJoystickHat(joy, pov_index, @as(u8, @intFromEnum(
                        states[state_index],
                    )));
                    pov_index += 1;
                },
            }
        }
    }
}

fn getMappingName() []const u8 {
    return "Windows";
}

fn updateGamepadGuid(guid: []const u8) void {
    if (std.mem.eql(u8, guid[20..], "504944564944")) {
        var original: [32]u8 = [1]u8{0} ** 32;
        @memcpy(&original, guid);
        std.fmt.bufPrint(
            &guid,
            "03000000{s:4}0000{s:4}000000000000",
            .{
                original[0..4],
                original[4..8],
            },
        ) catch {};
    }
}

fn pollMonitors() void {}
