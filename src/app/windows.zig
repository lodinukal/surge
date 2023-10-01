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

    pub fn initWindow(self: *WindowsApplication, window: *WindowsWindow, descriptor: app.WindowDescriptor) !void {
        try window.init(self, descriptor);
    }

    pub fn pumpEvents(self: *WindowsApplication) !void {
        _ = self;
        var msg: std.os.windows.user32.MSG = undefined;
        while (try std.os.windows.user32.peekMessageW(
            &msg,
            null,
            0,
            0,
            std.os.windows.user32.PM_REMOVE,
        ) == true) {
            _ = std.os.windows.user32.translateMessage(&msg);
            _ = std.os.windows.user32.dispatchMessageW(&msg);
        }
    }

    pub inline fn allocator(self: *WindowsApplication) std.mem.Allocator {
        return self.base.allocator;
    }
};

const WindowsWindow = struct {
    application: *WindowsApplication,
    hwnd: ?win32.foundation.HWND = null,

    should_close: bool = false,
    descriptor: app.WindowDescriptor,

    pub inline fn allocator(self: *WindowsWindow) std.mem.Allocator {
        return self.application.allocator();
    }

    pub fn init(window: *WindowsWindow, application: *WindowsApplication, descriptor: app.WindowDescriptor) !void {
        try registerClassOnce();
        window.application = application;
        window.descriptor = descriptor;
        window.hwnd = try window.buildWindow();
    }

    var class_registered: bool = false;
    const class_name = win32.zig.L("app");
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
            descriptor.width orelse win32.ui.windows_and_messaging.CW_USEDEFAULT,
            descriptor.height orelse win32.ui.windows_and_messaging.CW_USEDEFAULT,
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
                window_opt = @ptrFromInt(
                    @as(usize, @bitCast(win32.ui.windows_and_messaging.GetWindowLongPtrW(
                        wnd,
                        win32.ui.windows_and_messaging.GWLP_USERDATA,
                    ))),
                );
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
                // std.debug.print("{*}\n", .{window});
                window.setShouldClose(true);
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
