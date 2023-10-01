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
    base: *app.Application,

    pub fn init(base: *app.Application) !WindowsApplication {
        return .{
            .base = base,
        };
    }

    pub fn deinit(self: *WindowsApplication) void {
        _ = self;
    }

    pub fn createWindow(self: *WindowsApplication, descriptor: app.WindowDescriptor) !WindowsWindow {
        var window = try WindowsWindow.init(self.base.allocator, self, descriptor);
        return window;
    }

    pub fn pumpEvents(self: *WindowsApplication) void {
        _ = self;
        var msg = std.mem.zeroes(win32.ui.windows_and_messaging.MSG);
        if (win32.ui.windows_and_messaging.PeekMessageW(
            &msg,
            null,
            0,
            0,
            .REMOVE,
        ) == win32.zig.TRUE) {
            _ = win32.ui.windows_and_messaging.TranslateMessage(&msg);
            _ = win32.ui.windows_and_messaging.DispatchMessageW(&msg);
        }
    }
};

const WindowsWindow = struct {
    allocator: std.mem.Allocator,
    application: *WindowsApplication,
    hwnd: ?win32.foundation.HWND = null,

    should_close: bool = false,

    pub fn init(allocator: std.mem.Allocator, application: *WindowsApplication, descriptor: app.WindowDescriptor) !WindowsWindow {
        try registerClassOnce();
        var wnd: WindowsWindow = .{
            .allocator = allocator,
            .application = application,
        };
        wnd.hwnd = try buildWindow(&wnd, descriptor);
        return wnd;
    }

    var class_registered: bool = false;
    const class_name = win32.zig.L("app");
    fn registerClassOnce() !void {
        if (class_registered) {
            return;
        }
        class_registered = true;

        var wc = std.mem.zeroes(win32.ui.windows_and_messaging.WNDCLASSW);
        wc.style = win32.ui.windows_and_messaging.WNDCLASS_STYLES.initFlags(.{ .VREDRAW = 1, .HREDRAW = 1 });
        wc.lpfnWndProc = WindowsWindow.windowProc;
        wc.hInstance = try getHInstance();
        wc.hCursor = null;
        wc.hbrBackground = null;
        wc.lpszClassName = class_name;
        if (win32.ui.windows_and_messaging.RegisterClassW(&wc) == 0) return WindowsError.ClassRegistrationFailed;
    }

    fn buildWindow(self: *WindowsWindow, descriptor: app.WindowDescriptor) !win32.foundation.HWND {
        const converted_title = std.unicode.utf8ToUtf16LeWithNull(
            self.allocator,
            descriptor.title,
        ) catch
            return WindowsError.Utf16ToUtf8Failed;
        defer self.allocator.free(converted_title);
        var hwnd = win32.ui.windows_and_messaging.CreateWindowExW(
            win32.ui.windows_and_messaging.WINDOW_EX_STYLE.initFlags(.{}),
            class_name,
            converted_title,
            win32.ui.windows_and_messaging.WS_OVERLAPPEDWINDOW,
            win32.ui.windows_and_messaging.CW_USEDEFAULT,
            win32.ui.windows_and_messaging.CW_USEDEFAULT,
            descriptor.width orelse win32.ui.windows_and_messaging.CW_USEDEFAULT,
            descriptor.height orelse win32.ui.windows_and_messaging.CW_USEDEFAULT,
            null,
            null,
            try getHInstance(),
            @ptrCast(self),
        ) orelse return WindowsError.HwndCreationFailed;

        return hwnd;
    }

    pub fn deinit(self: *WindowsWindow) void {
        if (self.hwnd) |*hwnd| {
            _ = win32.ui.windows_and_messaging.DestroyWindow(hwnd.*);
            self.hwnd = null;
        }
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

    fn windowProc(
        wnd: win32.foundation.HWND,
        msg: std.os.windows.UINT,
        wparam: std.os.windows.WPARAM,
        lparam: std.os.windows.LPARAM,
    ) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT {
        var window: *WindowsWindow = window: {
            var window_opt: ?*WindowsWindow = null;
            if (msg == win32.ui.windows_and_messaging.WM_NCCREATE) {
                var cs: *win32.ui.windows_and_messaging.CREATESTRUCTW = @ptrFromInt(@as(usize, @bitCast(lparam)));
                window_opt = @alignCast(@ptrCast(cs.lpCreateParams));
                window_opt.?.hwnd = wnd;
                _ = win32.ui.windows_and_messaging.SetWindowLongPtrW(
                    wnd,
                    win32.ui.windows_and_messaging.GWLP_USERDATA,
                    @bitCast(@intFromPtr(window_opt)),
                );
            } else {
                window_opt = @ptrFromInt(@as(usize, @bitCast(
                    win32.ui.windows_and_messaging.GetWindowLongPtrW(
                        wnd,
                        win32.ui.windows_and_messaging.GWLP_USERDATA,
                    ),
                )));
            }
            break :window (window_opt orelse return win32.ui.windows_and_messaging.DefWindowProcW(
                wnd,
                msg,
                wparam,
                lparam,
            ));
        };

        switch (msg) {
            win32.ui.windows_and_messaging.WM_CLOSE => {
                window.setShouldClose(true);
                return 0;
            },
            win32.ui.windows_and_messaging.WM_DESTROY => {
                window.setShouldClose(true);
                return 0;
            },
            else => return win32.ui.windows_and_messaging.DefWindowProcW(wnd, msg, wparam, lparam),
        }
    }
};

fn getHInstance() !win32.foundation.HINSTANCE {
    var module = win32.system.library_loader.GetModuleHandleW(null);
    return module orelse return WindowsError.HInstanceNull;
}
