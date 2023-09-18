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
    disabled_cursor_window: ?*platform.InternalWindow = null,
    captured_cursor_window: ?*platform.InternalWindow = null,
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
    display_name: [32]std.os.windows.WCHAR,
    public_adapter_name: [32]u8,
    public_display_name: [32]u8,
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

extern const __ImageBase: win32.system.system_services.IMAGE_DOS_HEADER;

fn getInstanceHandle() win32.foundation.HINSTANCE {
    return @ptrCast(&__ImageBase);
}

fn loadLibraries() bool {
    platform.lib.platform_state.instance = getInstanceHandle();
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

fn unloadLibraries() void {
    if (platform.lib.platform_state.ntdll.instance) |instance| {
        library_loader.FreeLibrary(instance);
    }
}

fn createKeyTables() void {
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

fn helperWindowProc(
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

fn createHelperWindow() bool {
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

inline fn highByte(x: u16) u8 {
    return @as(u8, @intCast(x >> 8));
}

inline fn lowByte(x: u16) u8 {
    return @as(u8, @intCast(x & 0xFF));
}

pub inline fn hiword(dword: std.os.windows.DWORD) std.os.windows.WORD {
    return @as(std.os.windows.WORD, @bitCast(@as(u16, @intCast((dword >> 16) & 0xffff))));
}

pub inline fn loword(dword: std.os.windows.DWORD) std.os.windows.WORD {
    return @as(std.os.windows.WORD, @bitCast(@as(u16, @intCast(dword & 0xffff))));
}

inline fn makeLong(low: u16, high: u16) u32 {
    return @as(u32, @intCast(low)) | (@as(u32, @intCast(high)) << 16);
}

inline fn isEqualGuid(a: win32.zig.Guid, b: win32.zig.Guid) bool {
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
fn updateKeyNames() void {
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
            utf16leToUtf8Greedy(&keyname, &chars);
            return;
        }
    }
}

fn utf16leToUtf8Greedy(utf8: []u8, utf16le: []const u16) usize {
    var offset: usize = 0;
    var it = std.unicode.Utf16LeIterator.init(utf16le);
    var temp: [16]u8 = undefined;
    while (it.nextCodepoint() catch return offset) |codepoint| {
        const taken = std.unicode.utf8Encode(codepoint, temp) catch break;
        if (offset + taken >= utf8.len) break;
        @memcpy(utf8[offset..][0..taken], temp[0..taken]);
        offset += taken;
    }
    return offset;
}

fn init() bool {
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

fn deinit() void {
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
        .getCursorPos = getCursorPos,
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

        .freeMonitor = freeMonitor,
        .getMonitorPos = getMonitorPos,
        .getMonitorContentScale = getMonitorContentScale,
        .getMonitorWorkarea = getMonitorWorkarea,
        .getVideoModes = getVideoModes,
        .getVideoMode = getVideoMode,
        .getGammaRamp = getGammaRamp,
        .setGammaRamp = setGammaRamp,

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
    utf16leToUtf8Greedy(&name, di.tszInstanceName);
    {
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

// monitor
const gdi = win32.graphics.gdi;
fn monitorCallback(
    hmonitor: gdi.HMONITOR,
    hdc: gdi.HDC,
    rect: *win32.foundation.RECT,
    data: win32.foundation.LPARAM,
) callconv(.Win64) std.os.windows.BOOL {
    _ = rect;
    _ = hdc;

    var mi = std.mem.zeroes(gdi.MONITORINFOEXW);
    mi.__AnonymousBase_winuser_L13571_C43.cbSize = @sizeOf(gdi.MONITORINFOEXW);

    if (gdi.GetMonitorInfoW(hmonitor, @ptrCast(&mi)) == win32.zig.TRUE) {
        const internal_monitor: *platform.InternalMonitor = @ptrFromInt(@as(usize, @intCast(data)));
        if (std.mem.eql(u32, &mi.szDevice, &internal_monitor.platform.adapter_name)) {
            internal_monitor.platform.handle = hmonitor;
        }
    }

    return win32.zig.TRUE;
}

fn createMonitor(adapter: *gdi.DISPLAY_DEVICEW, display: ?*gdi.DISPLAY_DEVICEW) ?*platform.InternalMonitor {
    const name = blk: {
        const source = if (display) |found_display|
            found_display.DeviceString
        else
            adapter.DeviceString;
        break :blk std.unicode.utf16leToUtf8Alloc(platform.lib.allocator, &source) catch return null;
    };
    defer platform.lib.allocator.free(name);

    var dm = std.mem.zeroes(gdi.DEVMODEW);
    dm.dmSize = @sizeOf(gdi.DEVMODEW);
    gdi.EnumDisplaySettingsW(&adapter.DeviceName, gdi.ENUM_CURRENT_SETTINGS, &dm);

    var dc = gdi.CreateDCW(
        win32.zig.L("DISPLAY"),
        &adapter.DeviceName,
        null,
        null,
    );

    const width_mm: i32 = if (isWindows8Point1OrGreater())
        gdi.GetDeviceCaps(dc, gdi.HORZSIZE)
    else
        @intCast(dm.dmPelsWidth * 25.4 / gdi.GetDeviceCaps(dc, gdi.LOGPIXELSX));
    const height_mm: i32 = if (isWindows8Point1OrGreater())
        gdi.GetDeviceCaps(dc, gdi.VERTSIZE)
    else
        @intCast(dm.dmPelsHeight * 25.4 / gdi.GetDeviceCaps(dc, gdi.LOGPIXELSY));
    gdi.DeleteDC(dc);

    var internal_monitor = platform.allocateMonitor(
        name,
        width_mm,
        height_mm,
    ) catch return null;

    if ((adapter.StateFlags & gdi.DISPLAY_DEVICE_MODESPRUNED) != 0)
        internal_monitor.platform.modes_pruned = true;

    @memcpy(&internal_monitor.platform.adapter_name, &adapter.DeviceName);
    utf16leToUtf8Greedy(&internal_monitor.platform.public_adapter_name, &adapter.DeviceName);

    if (display) |found_display| {
        @memcpy(&internal_monitor.platform.display_name, &found_display.DeviceName);
        utf16leToUtf8Greedy(&internal_monitor.platform.public_display_name, &found_display.DeviceName);
    }

    var rect = std.mem.zeroes(win32.foundation.RECT);
    rect.left = dm.Anonymous1.Anonymous2.dmPosition.x;
    rect.top = dm.Anonymous1.Anonymous2.dmPosition.y;
    rect.right = dm.Anonymous1.Anonymous2.dmPosition.x + dm.dmPelsWidth;
    rect.bottom = dm.Anonymous1.Anonymous2.dmPosition.y + dm.dmPelsHeight;

    gdi.EnumDisplayMonitors(null, &rect, monitorCallback, @ptrCast(&internal_monitor));
}

fn pollMonitors() void {
    var disconnected_count: i32 = platform.lib.monitors.items.len;
    var disconnected: []?*platform.InternalMonitor = undefined;
    if (disconnected_count > 0) {
        disconnected = platform.lib.temp_arena_allocator.alloc(
            ?*platform.InternalMonitor,
            disconnected_count,
        ) catch return;
        for (0..disconnected_count) |index| {
            disconnected[index] = platform.lib.monitors.items[index];
        }
    }
    defer platform.lib.temp_arena.reset(.retain_capacity);

    var adapter_index: usize = 0;
    while (true) : (adapter_index += 1) {
        var insert_first = false;

        var adapter = std.mem.zeroes(gdi.DISPLAY_DEVICEW);
        adapter.cb = @sizeOf(gdi.DISPLAY_DEVICEW);

        if (gdi.EnumDisplayDevicesW(
            null,
            adapter_index,
            &adapter,
            0,
        ) != win32.zig.TRUE) {
            break;
        }

        if ((adapter.StateFlags & gdi.DISPLAY_DEVICE_ACTIVE) == 0) {
            continue;
        }

        if ((adapter.StateFlags & gdi.DISPLAY_DEVICE_PRIMARY_DEVICE) != 0) {
            insert_first = true;
        }

        var display_index: usize = 0;
        while (true) : (display_index += 1) {
            var display = std.mem.zeroes(gdi.DISPLAY_DEVICEW);
            display.cb = @sizeOf(gdi.DISPLAY_DEVICEW);

            if (gdi.EnumDisplayDevicesW(
                &adapter.DeviceName,
                display_index,
                &display,
                0,
            ) != win32.zig.TRUE) {
                break;
            }

            if ((display.StateFlags & gdi.DISPLAY_DEVICE_ACTIVE) == 0) {
                continue;
            }

            var set = false;
            blk: for (0..disconnected_count) |index| {
                if (disconnected[index]) |internal_monitor| if (std.mem.eql(
                    u32,
                    internal_monitor.platform.display_name,
                    display.DeviceName,
                )) {
                    disconnected[index] = null;
                    gdi.EnumDisplayMonitors(
                        null,
                        null,
                        monitorCallback,
                        @ptrCast(internal_monitor),
                    );
                    set = true;
                    break :blk;
                };
            }

            if (set) continue;

            var monitor = createMonitor(&adapter, &display) orelse return;
            platform.inputMonitorConnection(monitor, true, insert_first);
            insert_first = false;
        }

        if (display_index == 0) {
            var set = false;
            blk: for (0..disconnected_count) |index| {
                if (disconnected[index]) |internal_monitor| if (std.mem.eql(
                    u32,
                    internal_monitor.platform.adapter_name,
                    adapter.DeviceName,
                )) {
                    disconnected[index] = null;
                    set = true;
                    break :blk;
                };
            }

            if (set) continue;

            var monitor = createMonitor(&adapter, null) orelse return;
            platform.inputMonitorConnection(monitor, true, insert_first);
        }
    }

    for (disconnected) |display| if (display) |found_display| {
        platform.inputMonitorConnection(found_display, false, false);
    };
}

fn setVideoMode(mon: *platform.InternalMonitor, desired: *const definitions.VideoMode) void {
    const best = platform.chooseVideoMode(mon, desired) orelse return;

    var current = std.mem.zeroes(definitions.VideoMode);
    getVideoMode(mon, &current);
    if (current.order(best) == .eq) return;

    var dm = std.mem.zeroes(gdi.DEVMODEW);
    dm.dmSize = @sizeOf(gdi.DEVMODEW);
    dm.dmFields = gdi.DM_PELSWIDTH | gdi.DM_PELSHEIGHT | gdi.DM_BITSPERPEL | gdi.DM_DISPLAYFREQUENCY;
    dm.dmPelsWidth = best.width;
    dm.dmPelsHeight = best.height;
    dm.dmBitsPerPel = best.red_bits + best.green_bits + best.blue_bits;
    dm.dmDisplayFrequency = best.refresh_rate;

    if (dm.dmBitsPerPel < 15 or dm.dmBitsPerPel >= 24) {
        dm.dmBitsPerPel = 32;
    }

    const result = gdi.ChangeDisplaySettingsExW(
        &mon.platform.adapter_name,
        &dm,
        null,
        gdi.CDS_FULLSCREEN,
        null,
    );
    if (result == .SUCCESSFUL) {
        mon.platform.mode_changed = true;
    } else {
        main.setErrorString(switch (result) {
            .BADDUALVIEW => "The system uses DualView",
            .BADFLAGS => "An invalid set of flags was passed in",
            .BADMODE => "The graphics mode is not supported",
            .BADPARAM => "An invalid parameter was passed in",
            .FAILED => "The display driver failed the specified graphics mode",
            .NOTUPDATED => "Unable to write settings to the registry",
            .RESTART => "The computer must be restarted in order for the graphics mode to work",
            else => "Unknown error",
        });
    }
}

fn restoreVideoMode(mon: *platform.InternalMonitor) void {
    if (mon.platform.mode_changed) {
        gdi.ChangeDisplaySettingsExW(
            &mon.platform.adapter_name,
            null,
            null,
            gdi.CDS_FULLSCREEN,
            null,
        );
        mon.platform.mode_changed = false;
    }
}

const hi_dpi = win32.ui.hi_dpi;
fn getHmonitorContentScale(hmonitor: gdi.HMONITOR) ?definitions.FloatPosition {
    var result = definitions.FloatPosition{ .x = 1, .y = 1 };

    var x: u32 = 0;
    var y: u32 = 0;

    if (isWindows8Point1OrGreater()) {
        if (hi_dpi.GetDpiForMonitor(hmonitor, hi_dpi.MDT_EFFECTIVE_DPI, &x, &y) != win32.foundation.S_OK) {
            main.setErrorString("Failed to get DPI for monitor");
            return null;
        }
    } else {
        const dc = gdi.GetDC(null);
        defer gdi.ReleaseDC(null, dc);
        x = gdi.GetDeviceCaps(dc, gdi.LOGPIXELSX);
        y = gdi.GetDeviceCaps(dc, gdi.LOGPIXELSY);
    }

    result.x = @as(f32, @floatFromInt(x)) / wam.USER_DEFAULT_SCREEN_DPI;
    result.y = @as(f32, @floatFromInt(y)) / wam.USER_DEFAULT_SCREEN_DPI;
    return result;
}

fn freeMonitor(mon: *platform.InternalMonitor) void {
    _ = mon;
}

fn getMonitorPos(mon: *platform.InternalMonitor) definitions.Position {
    var dm = std.mem.zeroes(gdi.DEVMODEW);
    dm.dmSize = @sizeOf(gdi.DEVMODEW);

    gdi.EnumDisplaySettingsExW(
        &mon.platform.adapter_name,
        gdi.ENUM_CURRENT_SETTINGS,
        &dm,
        wam.EDS_ROTATEDMODE,
    );

    return definitions.Position{
        .x = dm.Anonymous1.Anonymous2.dmPosition.x,
        .y = dm.Anonymous1.Anonymous2.dmPosition.y,
    };
}

fn getMonitorContentScale(monitor: *platform.InternalMonitor) ?definitions.FloatPosition {
    return getHmonitorContentScale(monitor.platform.handle);
}

fn getMonitorWorkarea(mon: *platform.InternalMonitor) definitions.Rect {
    var mi = std.mem.zeroes(gdi.MONITORINFOEXW);
    mi.__AnonymousBase_winuser_L13571_C43.cbSize = @sizeOf(gdi.MONITORINFOEXW);
    gdi.GetMonitorInfoW(mon.platform.handle, &mi);

    return definitions.Rect{
        .x = mi.rcWork.left,
        .y = mi.rcWork.top,
        .width = mi.rcWork.right - mi.rcWork.left,
        .height = mi.rcWork.bottom - mi.rcWork.top,
    };
}

fn getVideoModes(
    mon: *platform.InternalMonitor,
) ?[]definitions.VideoMode {
    var index = 0;
    var modes = std.ArrayList(*definitions.VideoMode).init(platform.lib.allocator);

    loop: while (true) {
        var dm = std.mem.zeroes(gdi.DEVMODEW);
        dm.dmSize = @sizeOf(gdi.DEVMODEW);

        if (gdi.EnumDisplaySettingsW(
            &mon.platform.adapter_name,
            index,
            &dm,
        ) != win32.zig.TRUE) {
            break;
        }

        index += 1;

        if (dm.dmBitsPerPel < 15) break;

        var mode = definitions.VideoMode{
            .width = dm.dmPelsWidth,
            .height = dm.dmPelsHeight,
            .red_bits = null,
            .green_bits = null,
            .blue_bits = null,
            .refresh_rate = dm.dmDisplayFrequency,
        };

        const result = platform.splitBitsPerPixel(dm.dmBitsPerPel);
        mode.red_bits = result.red;
        mode.green_bits = result.green;
        mode.blue_bits = result.blue;

        for (modes.items) |item| {
            if (item.order(&mode) == .eq) {
                continue :loop;
            }
        }

        if (mon.platform.modes_pruned) {
            if (gdi.ChangeDisplaySettingsExW(
                &mon.platform.adapter_name,
                &dm,
                null,
                gdi.CDS_TEST,
                null,
            ) != gdi.DISP_CHANGE_SUCCESSFUL) {
                continue :loop;
            }
        }

        modes.append(mode) catch return null;
    }

    return modes.toOwnedSlice() catch return null;
}

fn getVideoMode(mon: *platform.InternalMonitor, mode: *definitions.VideoMode) void {
    var dm = std.mem.zeroes(gdi.DEVMODEW);
    dm.dmSize = @sizeOf(gdi.DEVMODEW);

    gdi.EnumDisplaySettingsW(&mon.platform.adapter_name, gdi.ENUM_CURRENT_SETTINGS, &dm);

    mode.width = dm.dmPelsWidth;
    mode.height = dm.dmPelsHeight;
    mode.refresh_rate = dm.dmDisplayFrequency;
    const result = platform.splitBitsPerPixel(dm.dmBitsPerPel);
    mode.red_bits = result.red;
    mode.green_bits = result.green;
    mode.blue_bits = result.blue;
}

fn getGammaRamp(mon: *platform.InternalMonitor) ?definitions.GammaRamp {
    var dc = gdi.CreateDCW(
        win32.zig.L("DISPLAY"),
        &mon.platform.adapter_name,
        null,
        null,
    );
    var values: [3][256]std.os.windows.WORD = [1][256]std.os.windows.WORD{[1]std.os.windows.WORD{0} ** 256} ** 3;
    win32.ui.color_system.GetDeviceGammaRamp(dc, @ptrCast(&values));
    gdi.DeleteDC(dc);

    var ramp = platform.allocateGammaRamp(256) catch return null;

    @memcpy(ramp.red[0..256], values[0]);
    @memcpy(ramp.green[0..256], values[1]);
    @memcpy(ramp.blue[0..256], values[2]);

    return ramp;
}

fn setGammaRamp(mon: *platform.InternalMonitor, ramp: *const definitions.GammaRamp) void {
    var dc = gdi.CreateDCW(
        win32.zig.L("DISPLAY"),
        &mon.platform.adapter_name,
        null,
        null,
    );

    var values: [3][256]std.os.windows.WORD = [1][256]std.os.windows.WORD{[1]std.os.windows.WORD{0} ** 256} ** 3;

    @memcpy(values[0], ramp.red[0..256]);
    @memcpy(values[1], ramp.green[0..256]);
    @memcpy(values[2], ramp.blue[0..256]);

    win32.ui.color_system.SetDeviceGammaRamp(dc, @ptrCast(&values));

    gdi.DeleteDC(dc);
}

// window
fn getWindowStyle(wnd: *const platform.InternalWindow) std.os.windows.DWORD {
    var style = @intFromEnum(wam.WS_CLIPSIBLINGS) | @intFromEnum(wam.WS_CLIPCHILDREN);

    if (wnd.monitor) {
        style |= @intFromEnum(wam.WS_POPUP);
    } else {
        style |= @intFromEnum(wam.WS_SYSMENU) | @intFromEnum(wam.WS_MINIMIZEBOX);

        if (wnd.decorated) {
            style |= @intFromEnum(wam.WS_CAPTION);

            if (wnd.resizable) {
                style |= @intFromEnum(wam.WS_MAXIMIZEBOX) | @intFromEnum(wam.WS_THICKFRAME);
            }
        } else {
            style |= @intFromEnum(wam.WS_POPUP);
        }
    }

    return style;
}

fn getWindowExStyle(wnd: *const platform.InternalWindow) std.os.windows.DWORD {
    var style = @intFromEnum(wam.WS_EX_APPWINDOW);

    if (wnd.monitor or wnd.floating) {
        style |= @intFromEnum(wam.WS_EX_TOPMOST);
    }

    return style;
}

fn chooseImage(images: []const definitions.Image, width: i32, height: i32) *const definitions.Image {
    var least_diff: i32 = std.math.maxInt(i32);

    var result: ?*const definitions.Image = null;

    for (images) |*img| {
        const diff = std.math.absInt(img.width * img.height - width * height);
        if (diff < least_diff) {
            result = img;
            least_diff = diff;
        }
    }

    return result.?;
}

fn createIcon(image: *const definitions.Image, xhot: i32, yhot: i32, icon: bool) ?wam.HICON {
    var bv5h = std.mem.zeroes(gdi.BITMAPV5HEADER);
    bv5h.bV5Size = @sizeOf(gdi.BITMAPV5HEADER);
    bv5h.bV5Width = image.width;
    bv5h.bV5Height = -image.height;
    bv5h.bV5Planes = 1;
    bv5h.bV5BitCount = 32;
    bv5h.bV5Compression = gdi.BI_BITFIELDS;
    bv5h.bV5RedMask = 0x00ff0000;
    bv5h.bV5GreenMask = 0x0000ff00;
    bv5h.bV5BlueMask = 0x000000ff;
    bv5h.bV5AlphaMask = 0xff000000;

    var dc = gdi.GetDC(null);
    var target: ?[*]u8 = null;
    var color = gdi.CreateDIBSection(
        dc,
        @ptrCast(&bv5h),
        gdi.DIB_RGB_COLORS,
        @ptrCast(&target),
        null,
        0,
    ) orelse {
        main.setErrorString("Failed to create RGBA bitmap");
        return null;
    };

    var mask = gdi.CreateBitmap(
        image.width,
        image.height,
        1,
        1,
        null,
    ) orelse {
        main.setErrorString("Failed to create mask bitmap");
        gdi.DeleteObject(color);
        return null;
    };

    const source = image.pixels;
    for (0..(image.width * image.height)) |index| {
        target[index * 4 + 0] = source[index * 4 + 2];
        target[index * 4 + 1] = source[index * 4 + 1];
        target[index * 4 + 2] = source[index * 4 + 0];
        target[index * 4 + 3] = source[index * 4 + 3];
    }

    var info = std.mem.zeroes(wam.ICONINFO);
    info.fIcon = icon;
    info.xHotspot = xhot;
    info.yHotspot = yhot;
    info.hbmMask = mask;
    info.hbmColor = color;

    var hicon = wam.CreateIconIndirect(@ptrCast(&info)) orelse {
        main.setErrorString(if (icon) "Failed to create icon" else "Failed to create cursor");
        gdi.DeleteObject(color);
        gdi.DeleteObject(mask);

        return null;
    };

    gdi.DeleteObject(color);
    gdi.DeleteObject(mask);

    return hicon;
}

fn applyAspectRatio(wnd: *platform.InternalWindow, edge: i32, area: *win32.foundation.RECT) void {
    var frame = std.mem.zeroes(win32.foundation.RECT);
    const style = getWindowStyle(wnd);
    const ex_style = getWindowExStyle(wnd);
    const ratio: f32 = @as(
        f32,
        @floatFromInt(wnd.numer),
    ) / @as(
        f32,
        @floatFromInt(wnd.denom),
    );

    if (isWindows10Version1607OrGreater()) {
        hi_dpi.AdjustWindowRectExForDpi(
            &frame,
            style,
            win32.zig.FALSE,
            ex_style,
            hi_dpi.GetDpiForWindow(wnd.platform.handle),
        );
    }

    if (edge == wam.WMSZ_LEFT or edge == wam.WMSZ_BOTTOMLEFT or
        edge == wam.WMSZ_RIGHT or edge == wam.WMSZ_BOTTOMRIGHT)
    {
        area.bottom = area.top + (frame.bottom - frame.top) + @as(i32, @intFromFloat(
            @as(f32, @floatFromInt((area.right - area.left) - (frame.right - frame.left))) / ratio,
        ));
    } else if (edge == wam.WMSZ_TOPLEFT or edge == wam.WMSZ_TOPRIGHT) {
        area.top = area.bottom - (frame.bottom - frame.top) - @as(i32, @intFromFloat(
            @as(f32, @floatFromInt((area.right - area.left) - (frame.right - frame.left))) / ratio,
        ));
    } else if (edge == wam.WMSZ_TOP or edge == wam.WMSZ_BOTTOM) {
        area.right = area.left + (frame.right - frame.left) + @as(i32, @intFromFloat(
            @as(f32, @floatFromInt((area.bottom - area.top) - (frame.bottom - frame.top))) * ratio,
        ));
    }
}

fn updateCursorImage(wnd: *platform.InternalWindow) void {
    if (wnd.cursor_mode == .normal or wnd.cursor_mode == .captured) {
        if (wnd.cursor) |cursor| {
            wam.SetCursor(cursor.platform.handle);
        } else {
            wam.SetCursor(wam.LoadCursorW(null, wam.IDC_ARROW));
        }
    } else {
        wam.SetCursor(null);
    }
}

fn captureCursor(wnd: *platform.InternalWindow) void {
    var clip_rect = std.mem.zeroes(win32.foundation.RECT);
    wam.GetClientRect(wnd.platform.handle, &clip_rect);
    gdi.ClientToScreen(wnd.platform.handle, @ptrCast(&clip_rect.left));
    gdi.ClientToScreen(wnd.platform.handle, @ptrCast(&clip_rect.right));
    wam.ClipCursor(&clip_rect);
    platform.lib.platform_state.captured_cursor_window = wnd;
}

fn releaseCursor() void {
    wam.ClipCursor(null);
    platform.lib.platform_state.captured_cursor_window = null;
}

fn enableRawMouseMotion(wnd: *platform.InternalWindow) void {
    const rid = input.RAWINPUTDEVICE{
        .usUsagePage = 0x01,
        .usUsage = 0x02,
        .dwFlags = 0,
        .hwndTarget = wnd.platform.handle,
    };

    if (input.RegisterRawInputDevices(
        &rid,
        1,
        @sizeOf(input.RAWINPUTDEVICE),
    ) == win32.zig.FALSE) {
        main.setErrorString("Failed to register raw input device");
    }
}

fn disableRawMouseMotion(wnd: *platform.InternalWindow) void {
    _ = wnd;
    const rid = input.RAWINPUTDEVICE{
        .usUsagePage = 0x01,
        .usUsage = 0x02,
        .dwFlags = input.RIDEV_REMOVE,
        .hwndTarget = null,
    };

    if (input.RegisterRawInputDevices(
        &rid,
        1,
        @sizeOf(input.RAWINPUTDEVICE),
    ) == win32.zig.FALSE) {
        main.setErrorString("Failed to unregister raw input device");
    }
}

fn disableCursor(wnd: *platform.InternalWindow) void {
    platform.lib.platform_state.disabled_cursor_window = wnd;
    const restore_pos = getCursorPos(wnd);

    platform.lib.platform_state.restore_cursor_pos_x = restore_pos.x;
    platform.lib.platform_state.restore_cursor_pos_y = restore_pos.y;

    updateCursorImage(wnd);
    platform.centreCursorInContentArea(wnd);
    captureCursor(wnd);

    if (wnd.raw_mouse_motion) {
        enableRawMouseMotion(wnd);
    }
}

fn enableCursor(wnd: *platform.InternalWindow) void {
    if (wnd.raw_mouse_motion) {
        disableRawMouseMotion(wnd);
    }

    platform.lib.platform_state.disabled_cursor_window = null;
    releaseCursor();
    setCursorPos(
        wnd,
        platform.lib.platform_state.restore_cursor_pos_x,
        platform.lib.platform_state.restore_cursor_pos_y,
    );
    updateCursorImage(wnd);
}

fn isCursorInContentArea(wnd: *platform.InternalWindow) bool {
    var cursor_pos = std.mem.zeroes(win32.foundation.POINT);
    if (wam.GetCursorPos(&cursor_pos) == win32.zig.FALSE) {
        return false;
    }

    if (wam.WindowFromPoint(cursor_pos) != wnd.platform.handle) {
        return false;
    }

    var area = std.mem.zeroes(win32.foundation.RECT);
    wam.GetClientRect(wnd.platform.handle, &area);
    gdi.ClientToScreen(wnd.platform.handle, @ptrCast(&area.left));
    gdi.ClientToScreen(wnd.platform.handle, @ptrCast(&area.right));

    return gdi.PtInRect(&area, cursor_pos) != win32.zig.FALSE;
}

fn updateWindowStyles(wnd: *const platform.InternalWindow) void {
    var style = wam.GetWindowLongW(wnd.platform.handle, wam.GWL_STYLE);
    style &= ~(@intFromEnum(wam.WS_OVERLAPPEDWINDOW) | @intFromEnum(wam.WS_POPUP));
    style |= getWindowStyle(wnd);

    const rect = std.mem.zeroes(win32.foundation.RECT);
    wam.GetClientRect(wnd.platform.handle, &rect);

    if (isWindows10Version1607OrGreater()) {
        hi_dpi.AdjustWindowRectExForDpi(
            &rect,
            style,
            win32.zig.FALSE,
            getWindowExStyle(wnd),
            hi_dpi.GetDpiForWindow(wnd.platform.handle),
        );
    } else {
        wam.AdjustWindowRectEx(
            &rect,
            style,
            win32.zig.FALSE,
            getWindowExStyle(wnd),
        );
    }

    gdi.ClientToScreen(wnd.platform.handle, @ptrCast(&rect.left));
    gdi.ClientToScreen(wnd.platform.handle, @ptrCast(&rect.right));
    wam.SetWindowLongW(wnd.platform.handle, wam.GWL_STYLE, style);
    wam.SetWindowPos(
        wnd.platform.handle,
        wam.HWND_TOPMOST,
        rect.left,
        rect.top,
        rect.right - rect.left,
        rect.bottom - rect.top,
        @intFromEnum(wam.SWP_NOZORDER) | @intFromEnum(wam.SWP_NOACTIVATE) | @intFromEnum(wam.SWP_FRAMECHANGED),
    );
}

fn updateFramebufferTransparency(wnd: *const platform.InternalWindow) void {
    if (!isWindowsVistaOrGreater()) return;

    var composition_enabled: win32.foundation.BOOL = win32.zig.FALSE;
    if (win32.zig.FAILED(
        wam.DwmIsCompositionEnabled(&composition_enabled),
    ) or composition_enabled == win32.zig.FALSE) {
        return;
    }

    var colour: std.os.windows.DWORD = 0;
    var is_opaque: win32.foundation.BOOL = win32.zig.FALSE;
    if (isWindows8OrGreater() or win32.zig.SUCCEEDED(
        win32.graphics.dwm.DwmGetColorizationColor(
            &colour,
            &is_opaque,
        ),
    ) and !is_opaque) {
        const region = gdi.CreateRectRgn(0, 0, -1, -1);
        var blur_behind = std.mem.zeroes(win32.graphics.dwm.DWM_BLURBEHIND);
        blur_behind.dwFlags = @intFromEnum(win32.graphics.dwm.DWM_BB_ENABLE) | @intFromEnum(
            win32.graphics.dwm.DWM_BB_BLURREGION,
        );
        blur_behind.hRgnBlur = region;
        blur_behind.fEnable = win32.zig.TRUE;

        win32.graphics.dwm.DwmEnableBlurBehindWindow(
            wnd.platform.handle,
            &blur_behind,
        );
        gdi.DeleteObject(region);
    } else {
        var blur_behind = std.mem.zeroes(win32.graphics.dwm.DWM_BLURBEHIND);
        blur_behind.dwFlags = @intFromEnum(win32.graphics.dwm.DWM_BB_ENABLE);

        win32.graphics.dwm.DwmEnableBlurBehindWindow(
            wnd.platform.handle,
            &blur_behind,
        );
    }
}

fn getKeyMods() definitions.Modifiers {
    return definitions.Modifiers{
        .shift = (kam.GetKeyState(kam.VK_SHIFT) & 0x8000) != 0,
        .ctrl = (kam.GetKeyState(kam.VK_CONTROL) & 0x8000) != 0,
        .alt = (kam.GetKeyState(kam.VK_MENU) & 0x8000) != 0,
        .super = (kam.GetKeyState(kam.VK_LWIN) & 0x8000) != 0 or
            (kam.GetKeyState(kam.VK_RWIN) & 0x8000) != 0,
        .caps_lock = (kam.GetKeyState(kam.VK_CAPITAL) & 0x0001) != 0,
        .num_lock = (kam.GetKeyState(kam.VK_NUMLOCK) & 0x0001) != 0,
    };
}

fn fitToMonitor(wnd: *platform.InternalWindow) void {
    var monitor_info = std.mem.zeroes(gdi.MONITORINFO);
    gdi.GetMonitorInfoW(wnd.platform.handle, &monitor_info);
    wam.SetWindowPos(
        wnd.platform.handle,
        null,
        monitor_info.rcMonitor.left,
        monitor_info.rcMonitor.top,
        monitor_info.rcMonitor.right - monitor_info.rcMonitor.left,
        monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top,
        @intFromEnum(wam.SWP_NOZORDER) | @intFromEnum(wam.SWP_NOACTIVATE) | @intFromEnum(wam.SWP_FRAMECHANGED),
    );
}

fn acquireMonitor(wnd: *platform.InternalWindow) void {
    if (platform.lib.platform_state.acquired_monitor_count == 0) {
        win32.system.power.SetThreadExecutionState(
            @intFromEnum(win32.system.power.ES_DISPLAY_REQUIRED) | @intFromEnum(win32.system.power.ES_CONTINUOUS),
        );
    }

    if (wnd.monitor.?.current_window == null) {
        platform.lib.platform_state.acquired_monitor_count += 1;
    }

    setVideoMode(wnd.monitor.?, &wnd.video_mode);
    platform.inputWindowMonitor(wnd, wnd.monitor.?);
}

fn releaseMonitor(wnd: *platform.InternalWindow) void {
    if (wnd.monitor.?.current_window != wnd) {
        return;
    }

    platform.lib.platform_state.acquired_monitor_count -= 1;

    if (platform.lib.platform_state.acquired_monitor_count == 0) {
        win32.system.power.SetThreadExecutionState(
            @intFromEnum(win32.system.power.ES_CONTINUOUS),
        );
    }

    platform.inputWindowMonitor(null, wnd.monitor.?);
    restoreVideoMode(wnd.monitor.?);
}

fn maximiseWindowManually(wnd: *platform.InternalWindow) void {
    var monitor_info = std.mem.zeroes(gdi.MONITORINFO);
    gdi.GetMonitorInfoW(gdi.MonitorFromWindow(wnd.platform.handle, .NEAREST), &monitor_info);

    var rect = monitor_info.rcWork;

    if (wnd.max_width != null and wnd.max_width != null) {
        rect.bottom = @min(rect.right, rect.left + wnd.max_width);
        rect.right = @min(rect.bottom, rect.top + wnd.max_height);
    }

    var style = wam.GetWindowLongW(wnd.platform.handle, ._STYLE);
    style |= @intFromEnum(wam.WS_MAXIMIZE);
    wam.SetWindowLongW(wnd.platform.handle, ._STYLE, style);

    if (wnd.decorated) {
        const ex_style = wam.GetWindowLongW(wnd.platform.handle, ._EXSTYLE);
        if (isWindows10Version1607OrGreater()) {
            const dpi = hi_dpi.GetDpiForWindow(wnd.platform.handle);
            hi_dpi.AdjustWindowRectExForDpi(
                &rect,
                style,
                win32.zig.FALSE,
                ex_style,
                dpi,
            );
            gdi.OffsetRect(
                &rect,
                0,
                hi_dpi.GetSystemMetricsForDpi(@intFromEnum(wam.SM_CYCAPTION), dpi),
            );
        } else {
            wam.AdjustWindowRectEx(
                &rect,
                style,
                win32.zig.FALSE,
                ex_style,
            );
            gdi.OffsetRect(
                &rect,
                0,
                wam.GetSystemMetrics(.CYCAPTION),
            );
        }

        rect.bottom = @min(rect.bottom, monitor_info.rcWork.bottom);
    }

    wam.SetWindowPos(
        wnd.platform.handle,
        wam.HWND_TOPMOST,
        rect.left,
        rect.top,
        rect.right - rect.left,
        rect.bottom - rect.top,
        @intFromEnum(wam.SWP_NOZORDER) | @intFromEnum(wam.SWP_NOACTIVATE) | @intFromEnum(wam.SWP_FRAMECHANGED),
    );
}

fn windowProc(
    hwnd: ?win32.foundation.HWND,
    msg: std.os.windows.UINT,
    wparam: std.os.windows.WPARAM,
    lparam: std.os.windows.LPARAM,
) callconv(.Win64) win32.foundation.LRESULT {
    var wnd_opt: ?*platform.InternalWindow = wam.GetPropW(hwnd, win32.zig.L("wam_window"));
    if (wnd_opt == null) {
        if (msg == @intFromEnum(wam.WM_NCCREATE)) {
            if (isWindows10Version1607OrGreater()) {
                const cs: *const wam.CREATESTRUCTW = @ptrCast(lparam);
                const wnd_config: ?*const definitions.WindowConfig = @ptrCast(cs.lpCreateParams);
                if (wnd_config) |config| if (config.scale_to_monitor) {
                    hi_dpi.EnableNonClientDpiScaling(hwnd);
                };
            }
        }

        return wam.DefWindowProcW(hwnd, msg, wparam, lparam);
    }
    const wnd = wnd_opt.?;

    switch (msg) {
        wam.WM_MOUSEACTIVATE => {
            if (hiword(lparam) == @intFromEnum(wam.WM_LBUTTONDOWN)) {
                if (loword(lparam) != @intFromEnum(wam.HTCLIENT)) {
                    wnd.platform.frame_action = true;
                }
            }
        },
        wam.WM_CAPTURECHANGED => {
            if (wnd.platform.frame_action and lparam == 0) {
                if (wnd.cursor_mode == .disabled) {
                    disableCursor(wnd);
                } else if (wnd.cursor_mode == .captured) {
                    captureCursor(wnd);
                }
                wnd.platform.frame_action = false;
            }
        },
        wam.WM_SETFOCUS => {
            platform.inputWindowFocus(wnd, true);

            if (!wnd.platform.frame_action) {
                if (wnd.cursor_mode == .disabled) {
                    disableCursor(wnd);
                } else if (wnd.cursor_mode == .captured) {
                    captureCursor(wnd);
                }
                return 0;
            }
        },
        wam.WM_KILLFOCUS => {
            if (wnd.cursor_mode == .disabled) {
                enableCursor(wnd);
            } else if (wnd.cursor_mode == .captured) {
                releaseCursor();
            }

            if (wnd.monitor != null and wnd.auto_iconify) {
                iconifyWindow(wnd);
            }

            platform.inputWindowFocus(wnd, false);
            return 0;
        },
        wam.WM_SYSCOMMAND => {
            switch (wparam & 0xfff0) {
                gdi.SC_SCREENSAVE, SC_MONITORPOWER => {
                    if (wnd.monitor != null) return 0;
                },
                SC_KEYMENU => {
                    if (!wnd.platform.keymenu) return 0;
                },
                else => {},
            }
        },
        wam.WM_CLOSE => {
            platform.inputWindowCloseRequest(wnd);
        },
        wam.WM_INPUTLANGCHANGE => {
            updateKeyNames();
        },
        wam.WM_CHAR, wam.WM_SYSCHAR => {
            if (wparam >= 0xd800 and wparam <= 0xdbff) {
                wnd.platform.high_surrogate = @truncate(wparam);
            } else {
                var cp: u32 = 0;

                if (wparam >= 0xdc00 and wparam <= 0xdfff) {
                    if (wnd.platform.high_surrogate != 0) {
                        cp += (wnd.platform.high_surrogate - 0xd800) << 10;
                        cp += (wparam - 0xdc00);
                        cp += 0x10000;
                    }
                } else cp = @truncate(wparam);

                wnd.platform.high_surrogate = 0;
                platform.inputChar(
                    wnd,
                    @truncate(cp),
                    getKeyMods(),
                    msg != @intFromEnum(wam.WM_SYSCHAR),
                );
            }

            if (msg == @intFromEnum(wam.WM_CHAR) or wnd.platform.keymenu) {
                return 0;
            }
        },
        WM_UNICHAR => {
            if (wparam == wam.UNICODE_NOCHAR) {
                return win32.zig.TRUE;
            }

            platform.inputChar(wnd, @truncate(wparam), getKeyMods(), true);
        },
        wam.WM_KEYDOWN, wam.WM_SYSKEYDOWN, wam.WM_KEYUP, wam.WM_SYSKEYUP => {
            const action: definitions.ElementState = if (hiword(lparam) & wam.KF_UP != null) .release else .press;
            _ = action;
            const mods = getKeyMods();
            _ = mods;

            const scancode = hiword(lparam) & (@intFromEnum(wam.KF_EXTENDED) | 0xff);
            if (scancode == 0) {
                scancode = kam.MapVirtualKeyW(
                    @intCast(wparam),
                    @intFromEnum(wam.MAPVK_VK_TO_VSC),
                );
            }
        },
    }
}

const SC_MONITORPOWER: u32 = 0xf170;
const SC_KEYMENU: u32 = 0xf100;
const WM_UNICHAR: u32 = 0x0109;

fn getCursorPos(wnd: *platform.InternalWindow) definitions.DoublePosition {
    _ = wnd;
    return .{ .x = 0.0, .y = 0.0 };
}

fn setCursorPos(wnd: *platform.InternalWindow, x: f64, y: f64) void {
    _ = wnd;
    _ = x;
    _ = y;
}

fn iconifyWindow(wnd: *platform.InternalWindow) void {
    _ = wnd;
}
