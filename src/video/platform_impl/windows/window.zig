const std = @import("std");

const windows_platform = @import("windows.zig");
const windows_dpi = @import("dpi.zig");
const windows_ime = @import("ime.zig");
const windows_theme = @import("theme.zig");

const win32 = @import("win32");
const common = @import("../../../core/common.zig");

const windows_window_state = @import("window_state.zig");

const dpi = @import("../../dpi.zig");
const icon = @import("../../icon.zig");
const window = @import("../../window.zig");

const dwm = win32.graphics.dwm;
const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const wam = win32.ui.windows_and_messaging;
const z32 = win32.zig;

pub const PlatformSpecificWindowAttributes = struct {
    owner: ?foundation.HWND = null,
    menu: ?foundation.HMENU = null,
    taskbar_icon: ?icon.Icon = null,
    no_redirection_bitmap: bool = false,
    drag_and_drop: bool = true,
    skip_taskbar: bool = false,
    class_name: []const u8 = "wndclass",
    decoration_shadow: bool = false,
};

pub const WindowHandle = struct {
    wnd: foundation.HWND,
    window_state: windows_window_state.WindowState,

    pub fn init(
        window_attributes: window.WindowAttributes,
        platform_attributes: PlatformSpecificWindowAttributes,
        allocator: std.mem.Allocator,
    ) !WindowHandle {
        const title = std.unicode.utf8ToUtf16LeWithNull(allocator, window_attributes.title);
        const class_name = std.unicode.utf8ToUtf16LeWithNull(allocator, platform_attributes.class_name);
        registerWindowClass(class_name);

        var window_flags = windows_window_state.WindowFlags{};
        window_flags.decorations = window_attributes.decorations;
        window_flags.undecorated_shadow = platform_attributes.decoration_shadow;
        window_flags.always_on_top = window_attributes.window_level == .always_on_top;
        window_flags.always_on_bottom = window_attributes.window_level == .always_on_bottom;
        window_flags.no_back_buffer = platform_attributes.no_redirection_bitmap;
        window_flags.activate = window_attributes.active;
        window_flags.transparent = window_attributes.transparent;
        window_flags.resizable = window_attributes.resizable;
        window_flags.closable = true;

        const parent = blk: {
            if (platform_attributes.owner) |parent| {
                window_flags.popup = true;
                break :blk parent;
            }
            window_flags.on_taskbar = true;
            break :blk null;
        };

        const styles = window_flags.toWindowStyles();
        const style = styles.@"0";
        const ex_style = styles.@"1";

        var data = WindowInitData{
            .attributes = window_attributes,
            .platform_attributes = platform_attributes,
            .window_flags = window_flags,
            .window = null,
            .allocator = allocator,
        };

        const handle = wam.CreateWindowExW(
            ex_style,
            class_name,
            title,
            style,
            wam.CW_USEDEFAULT,
            wam.CW_USEDEFAULT,
            wam.CW_USEDEFAULT,
            wam.CW_USEDEFAULT,
            parent,
            platform_attributes.menu,
            windows_platform.getInstanceHandle(),
            @ptrCast(&data),
        );

        if (handle == 0) {
            return error.WindowCreationError;
        }

        return data.window.?;
    }
};

const WindowInitData = struct {
    attributes: window.WindowAttributes,
    platform_attributes: PlatformSpecificWindowAttributes,
    window_flags: windows_window_state.WindowFlags,
    window: ?WindowHandle,
    allocator: std.mem.Allocator,

    pub fn createWindow(wid: *const WindowInitData, wnd: foundation.HWND) WindowHandle {
        const digitiser: u32 = wam.GetSystemMetrics(wam.SM_DIGITIZER);
        if (digitiser & wam.NID_READY != 0) {
            wam.RegisterTouchWindow(wnd, wam.TWF_WANTPALM);
        }

        const wnd_dpi = windows_dpi.hwndDpi(wnd);
        const scale_factor = windows_dpi.dpiToScaleFactor(wnd_dpi);

        const current_theme = windows_theme.tryTheme(wnd, wid.attributes.preferred_theme);

        const window_state = blk: {
            const in_state = windows_window_state.WindowState.init(
                &wid.attributes,
                scale_factor,
                current_theme,
                wid.attributes.preferred_theme,
            );
            in_state.setWindowFlags(wnd, wid, struct {
                pub fn set(passed_wid: *WindowInitData, wf: *windows_window_state.WindowFlags) void {
                    wf.* = passed_wid.window_flags;
                }
            }.set);
            break :blk in_state;
        };

        windows_dpi.enableNonClientDpiScaling(wnd);
        windows_ime.ImeContext.setImeAllowed(wnd, false);
        return WindowHandle{
            .wnd = wnd,
            .window_state = window_state,
        };
    }

    pub fn createWindowData(wid: *const WindowInitData, wnd: *const WindowHandle) WindowData {
        _ = wid;
        return WindowData{
            .window_state = wnd.window_state,
        };
    }

    pub fn onNcCreate(wid: *WindowInitData, wnd: foundation.HWND) *WindowData {
        const created_window = wid.createWindow(wnd);
        const created_window_data = wid.createWindowData(&created_window);
        wid.window = created_window;
        const userdata = wid.allocator.create(WindowData);
        userdata.* = created_window_data;
        return userdata;
    }

    pub fn onCreate(wid: *WindowInitData) void {
        const win = wid.window;
        common.assert(win != null, "Window does not exist\n", .{});

        if (wid.attributes.transparent and !wid.platform_attributes.no_redirection_bitmap) {
            const region = gdi.CreateRectRgn(0, 0, -1, -1);
            const bb = dwm.DWM_BLURBEHIND{
                .dwFlags = dwm.DWM_BB_ENABLE | dwm.DWM_BB_BLURREGION,
                .fEnable = true,
                .hRgnBlur = region,
                .fTransitionOnMaximized = z32.FALSE,
            };
            const hres = dwm.DwmEnableBlurBehindWindow(win.?.wnd, &bb);
            if (hres < 0) {
                common.err("Setting transparent window is failed, HRESULT: 0x{:X}", .{hres});
            }
            gdi.DeleteObject(region);
        }

        // TODO: Set properties of windows
        //   win.?.(propset)
    }
};

pub fn registerWindowClass(class_name: [*:0]const u16) void {
    const class = wam.WNDCLASSEXW{
        .cbSize = @sizeOf(wam.WNDCLASSEXW),
        .style = wam.CS_HREDRAW | wam.CS_VREDRAW,
        .lpfnWndProc = wam.DefWindowProcW,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = windows_platform.getInstanceHandle(),
        .hIcon = null,
        .hCursor = null,
        .lpszMenuName = null,
        .lpszClassName = class_name,
        .hIconSm = null,
    };

    wam.RegisterClassExW(*class);
}

const WindowData = struct {
    window_state: windows_window_state.WindowState,
};
