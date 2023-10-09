const std = @import("std");

const app = @import("app.zig");

const win32 = @import("win32");

pub const Error = WindowsError;
pub const Application = WindowsApplication;
pub const Window = WindowsWindow;

const WindowsError = error{
    Utf16ToUtf8Failed,
    HwndCreationFailed,
    HwndDestroyFailed,
    ClassRegistrationFailed,
    HInstanceNull,
};

const WindowsApplication = struct {
    base: *app.Application = undefined,

    pub fn init(self: *WindowsApplication, base: *app.Application) !void {
        self.base = base;
    }

    pub fn deinit(self: *WindowsApplication) void {
        _ = self;
    }

    pub fn initWindow(self: *WindowsApplication, base: *app.Window, window: *WindowsWindow, descriptor: app.WindowDescriptor) !void {
        try window.init(base, self, descriptor);
    }

    pub fn pumpEvents(self: *WindowsApplication) !void {
        _ = self;
        var msg: win32.ui.windows_and_messaging.MSG = undefined;
        while (win32.ui.windows_and_messaging.PeekMessageW(
            &msg,
            null,
            0,
            0,
            win32.ui.windows_and_messaging.PM_REMOVE,
        ) != -1) {
            _ = win32.ui.windows_and_messaging.TranslateMessage(&msg);
            _ = win32.ui.windows_and_messaging.DispatchMessageW(&msg);
        }
    }

    pub inline fn allocator(self: *WindowsApplication) std.mem.Allocator {
        return self.base.allocator;
    }
};

const WindowsWindow = struct {
    var class_registered: bool = false;
    const class_name = win32.zig.L("app");

    base: *app.Window = undefined,
    application: *WindowsApplication,
    hwnd: ?win32.foundation.HWND = null,

    should_close: bool = false,
    descriptor: app.WindowDescriptor,

    non_fullscreen_window_placement: win32.ui.windows_and_messaging.WINDOWPLACEMENT = undefined,

    pub inline fn allocator(self: *WindowsWindow) std.mem.Allocator {
        return self.application.allocator();
    }

    pub fn init(self: *WindowsWindow, base: *app.Window, application: *WindowsApplication, descriptor: app.WindowDescriptor) !void {
        try registerClassOnce();
        self.base = base;
        self.application = application;
        self.descriptor = descriptor;
        self.hwnd = try self.buildWindow();
    }

    fn registerClassOnce() !void {
        if (class_registered) {
            return;
        }
        class_registered = true;

        var wc = std.mem.zeroes(win32.ui.windows_and_messaging.WNDCLASSW);
        wc.style = win32.ui.windows_and_messaging.WNDCLASS_STYLES.initFlags(.{
            .VREDRAW = 1,
            .HREDRAW = 1,
            .OWNDC = 1,
            .DBLCLKS = 1,
        });
        wc.lpfnWndProc = WindowsWindow.windowProc;
        wc.hInstance = try getHInstance();
        wc.hCursor = win32.ui.windows_and_messaging.LoadCursorW(
            null,
            win32.ui.windows_and_messaging.IDC_ARROW,
        );
        wc.hbrBackground = win32.graphics.gdi.GetStockObject(.WHITE_BRUSH);
        wc.lpszClassName = class_name;
        wc.cbClsExtra = 0;
        wc.cbWndExtra = 0;
        wc.hIcon = win32.ui.windows_and_messaging.LoadIconW(
            null,
            win32.ui.windows_and_messaging.IDI_APPLICATION,
        );
        wc.lpszMenuName = null;

        if (win32.ui.windows_and_messaging.RegisterClassW(&wc) == 0) return WindowsError.ClassRegistrationFailed;
    }

    fn buildWindow(self: *WindowsWindow) !win32.foundation.HWND {
        const descriptor = self.descriptor;
        var stack_allocator = std.heap.stackFallback(1024, self.allocator());
        var temp_allocator = stack_allocator.get();
        const converted_title = std.unicode.utf8ToUtf16LeWithNull(
            temp_allocator,
            descriptor.title,
        ) catch
            return WindowsError.Utf16ToUtf8Failed;
        defer temp_allocator.free(converted_title);
        var hwnd = win32.ui.windows_and_messaging.CreateWindowExW(
            win32.ui.windows_and_messaging.WINDOW_EX_STYLE.initFlags(.{}),
            class_name,
            converted_title,
            win32.ui.windows_and_messaging.WINDOW_STYLE.initFlags(.{
                .CLIPCHILDREN = 1,
                .CLIPSIBLINGS = 1,
                .SYSMENU = 1,
                .GROUP = 1,
                .CAPTION = 1,
                .THICKFRAME = 1,
                .TABSTOP = 1,
                .VISIBLE = 1,
            }),
            win32.ui.windows_and_messaging.CW_USEDEFAULT,
            win32.ui.windows_and_messaging.CW_USEDEFAULT,
            descriptor.width,
            descriptor.height,
            null,
            null,
            try getHInstance(),
            @ptrCast(self),
        ) orelse return WindowsError.HwndCreationFailed;

        _ = win32.ui.windows_and_messaging.SetWindowLongPtrW(
            hwnd,
            .P_USERDATA,
            @intCast(@intFromPtr(self)),
        );

        return hwnd;
    }

    pub fn deinit(self: *WindowsWindow) void {
        if (self.hwnd) |hwnd| {
            _ = win32.ui.windows_and_messaging.DestroyWindow(hwnd);
        }
        self.hwnd = null;
    }

    pub fn show(self: *WindowsWindow, should_show: bool) void {
        _ = win32.ui.windows_and_messaging.ShowWindow(self.hwnd, if (should_show) .SHOW else .HIDE);
    }

    pub fn shouldClose(self: *const WindowsWindow) bool {
        return self.should_close;
    }

    pub fn setShouldClose(self: *WindowsWindow, should_close: bool) void {
        self.should_close = should_close;
    }

    const HWND_TOP: ?win32.foundation.HWND = null;
    pub fn setFullscreen(
        self: *WindowsWindow,
        mode: app.FullscreenMode,
    ) void {
        if (mode == self.descriptor.fullscreen_mode) {
            return;
        }
        const previous_mode = self.descriptor.fullscreen_mode;
        self.descriptor.fullscreen_mode = mode;
        var current_style = win32.ui.windows_and_messaging.GetWindowLongW(
            self.hwnd,
            ._STYLE,
        );
        var styles = self.getStyles();
        current_style &= ~@intFromEnum(Styles.mask);
        current_style = @bitCast(@intFromEnum(app.orEnum(
            Styles.ws,
            .{ current_style, styles.style },
        )));
        _ = win32.ui.windows_and_messaging.SetWindowLongW(
            self.hwnd,
            ._STYLE,
            current_style,
        );

        if (previous_mode == .windowed and mode == .fullscreen) {
            self.non_fullscreen_window_placement.length = @sizeOf(win32.ui.windows_and_messaging.WINDOWPLACEMENT);
            _ = win32.ui.windows_and_messaging.GetWindowPlacement(
                self.hwnd,
                &self.non_fullscreen_window_placement,
            );

            var mi: win32.graphics.gdi.MONITORINFO = undefined;
            mi.cbSize = @sizeOf(win32.graphics.gdi.MONITORINFO);
            _ = win32.graphics.gdi.GetMonitorInfoW(
                win32.graphics.gdi.MonitorFromWindow(
                    self.hwnd,
                    .NEAREST,
                ),
                &mi,
            );

            _ = win32.ui.windows_and_messaging.SetWindowPos(
                self.hwnd,
                HWND_TOP,
                mi.rcMonitor.left,
                mi.rcMonitor.top,
                mi.rcMonitor.right - mi.rcMonitor.left,
                mi.rcMonitor.bottom - mi.rcMonitor.top,
                app.orEnum(win32.ui.windows_and_messaging.SET_WINDOW_POS_FLAGS, .{
                    .NOOWNERZORDER,
                    .DRAWFRAME,
                }),
            );
        }

        if (previous_mode == .fullscreen and mode == .windowed) {
            _ = win32.ui.windows_and_messaging.SetWindowPlacement(
                self.hwnd,
                &self.non_fullscreen_window_placement,
            );
            _ = win32.ui.windows_and_messaging.SetWindowPos(
                self.hwnd,
                null,
                0,
                0,
                0,
                0,
                app.orEnum(win32.ui.windows_and_messaging.SET_WINDOW_POS_FLAGS, .{
                    .NOMOVE,
                    .NOSIZE,
                    .NOZORDER,
                    .NOOWNERZORDER,
                    .DRAWFRAME,
                }),
            );
        }
    }

    const Styles = struct {
        style: ws,
        ex: wexs,
        const ws = win32.ui.windows_and_messaging.WINDOW_STYLE;
        const wexs = win32.ui.windows_and_messaging.WINDOW_EX_STYLE;
        // yoinked from https://github.com/libsdl-org/SDL/blob/main/src/video/windows/SDL_windowswindow.c#L94
        const basic = ws.initFlags(.{
            .CLIPSIBLINGS = 1,
            .CLIPCHILDREN = 1,
        });
        const fullscreen = ws.initFlags(.{
            .POPUP = 1,
            .GROUP = 1, // MINIMIZEBOX
        });
        const borderless = ws.initFlags(.{
            .POPUP = 1,
            .GROUP = 1, // MINIMIZEBOX
        });
        const borderless_windowed = ws.initFlags(.{
            .POPUP = 1,
            .CAPTION = 1,
            .SYSMENU = 1,
            .GROUP = 1, // MINIMIZEBOX
        });
        const normal = ws.initFlags(.{
            .OVERLAPPED = 1,
            .CAPTION = 1,
            .SYSMENU = 1,
            .GROUP = 1,
        });
        const resizable = ws.initFlags(.{
            .THICKFRAME = 1,
            .TABSTOP = 1,
        });
        const mask: ws = app.orEnum(ws, .{
            fullscreen,
            borderless,
            normal,
            resizable,
        });
    };

    fn getStyles(self: *const WindowsWindow) Styles {
        const ws = win32.ui.windows_and_messaging.WINDOW_STYLE;
        const wexs = win32.ui.windows_and_messaging.WINDOW_EX_STYLE;
        var styles: Styles = .{
            .style = ws.initFlags(.{}),
            .ex = wexs.initFlags(.{}),
        };
        const descriptor = self.descriptor;

        if (descriptor.is_popup) {
            styles.style = app.orEnum(ws, .{ styles.style, .POPUP });
        } else if (descriptor.fullscreen_mode == .fullscreen) {
            styles.style = app.orEnum(ws, .{ styles.style, Styles.fullscreen });
        } else {
            if (descriptor.borderless) {
                styles.style = app.orEnum(ws, .{ styles.style, Styles.borderless_windowed });
            } else {
                styles.style = app.orEnum(ws, .{ styles.style, Styles.normal });
            }

            if (descriptor.resizable) {
                if (!descriptor.borderless) {
                    styles.style = app.orEnum(ws, .{ styles.style, Styles.resizable });
                }
            }

            if (descriptor.open_minimised) {
                styles.style = app.orEnum(ws, .{ styles.style, .MINIMIZE });
            }
        }

        if (descriptor.is_popup) {
            styles.ex = app.orEnum(wexs, .{ styles.ex, .TOOLWINDOW, .NOACTIVATE });
        }

        return styles;
    }

    fn windowFromHwnd(hwnd: win32.foundation.HWND) ?*WindowsWindow {
        return @ptrFromInt(@as(
            usize,
            @intCast(win32.ui.windows_and_messaging.GetWindowLongPtrW(
                hwnd,
                .P_USERDATA,
            )),
        ));
    }

    fn windowProc(
        wnd: win32.foundation.HWND,
        msg: std.os.windows.UINT,
        wparam: std.os.windows.WPARAM,
        lparam: std.os.windows.LPARAM,
    ) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT {
        var window: *WindowsWindow = window: {
            var window_opt: ?*WindowsWindow = @ptrFromInt(
                @as(usize, @bitCast(win32.ui.windows_and_messaging.GetWindowLongPtrW(
                    wnd,
                    win32.ui.windows_and_messaging.GWLP_USERDATA,
                ))),
            );
            break :window (window_opt orelse return win32.ui.windows_and_messaging.DefWindowProcW(
                wnd,
                msg,
                wparam,
                lparam,
            ));
        };

        switch (msg) {
            win32.ui.windows_and_messaging.WM_CLOSE => {
                // std.debug.print("{*}\n", .{window});
                window.setShouldClose(true);
            },
            win32.ui.windows_and_messaging.WM_KEYDOWN => {
                if (wparam == @intFromEnum(win32.ui.input.keyboard_and_mouse.VK_F)) {
                    window.setFullscreen(if (window.descriptor.fullscreen_mode == .windowed) .fullscreen else .windowed);
                }
            },
            else => {},
        }

        return win32.ui.windows_and_messaging.DefWindowProcW(wnd, msg, wparam, lparam);
    }
};

fn getHInstance() !win32.foundation.HINSTANCE {
    var module = win32.system.library_loader.GetModuleHandleW(null);
    return module orelse return WindowsError.HInstanceNull;
}
