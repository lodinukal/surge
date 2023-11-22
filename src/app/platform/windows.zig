const std = @import("std");

const app = @import("../app.zig");
const math = @import("../../math.zig");
const util = @import("../../util.zig");
const trait = @import("../../core/trait.zig");
const channel = @import("../../core/channel.zig");

const winapi = @import("win32");
const winapizig = winapi.zig;
const win32 = winapi.windows.win32;
const gdk = winapi.microsoft.gdk;

pub const FALSE = win32.foundation.FALSE;
pub const TRUE = win32.foundation.TRUE;

pub const Error = WindowsError;
pub const Application = WindowsApplication;
pub const Window = WindowsWindow;
pub const Input = WindowsInput;
pub const NativeHandle = win32.foundation.HWND;

const WindowsError = error{
    StringConversionFailed,
    HwndCreationFailed,
    HwndDestroyFailed,
    ClassRegistrationFailed,
    HInstanceNull,
    AllocationFailed,
    UnexpectedRegistryValueType,
    RegistryError,
};

const WindowsApplication = struct {
    fn getBase(self: *WindowsApplication) *app.Application {
        return @fieldParentPtr(app.Application, "platform_application", self);
    }

    pub inline fn allocator(self: *WindowsApplication) std.mem.Allocator {
        return self.getBase().allocator;
    }

    pub fn init(self: *WindowsApplication) !void {
        _ = self;
    }

    pub fn deinit(self: *WindowsApplication) void {
        _ = self;
    }

    pub fn pumpEvents(self: *WindowsApplication) !void {
        _ = self;
        var msg: win32.ui.windows_and_messaging.MSG = undefined;
        while (result: {
            var x = win32.ui.windows_and_messaging.PeekMessageW(
                &msg,
                null,
                0,
                0,
                win32.ui.windows_and_messaging.PM_REMOVE,
            );
            if (x == 0) break :result false;
            if (x != -1) break :result true;
            switch (win32.foundation.GetLastError()) {
                .ERROR_INVALID_WINDOW_HANDLE => unreachable,
                .ERROR_INVALID_PARAMETER => unreachable,
                else => |err| return std.os.windows.unexpectedError(@enumFromInt(
                    @intFromEnum(
                        err,
                    ),
                )),
            }
        }) {
            _ = win32.ui.windows_and_messaging.TranslateMessage(&msg);
            _ = win32.ui.windows_and_messaging.DispatchMessageW(&msg);
        }
    }
};

const WindowsWindow = struct {
    var class_registered: bool = false;
    const class_name = winapizig.L("app");
    const Modified = struct {
        descriptor: app.window.WindowDescriptor = undefined,
        title_changed: bool = false,
        use_client_area: bool = false,
        size_changed: bool = false,
    };

    hwnd: ?win32.foundation.HWND = null,

    should_close: bool = false,
    focused: bool = false,
    descriptor: app.window.WindowDescriptor,
    modified_state: Modified,

    non_fullscreen_window_placement: win32.ui.windows_and_messaging.WINDOWPLACEMENT = undefined,

    fn getBase(self: *WindowsWindow) *app.window.Window {
        return @fieldParentPtr(app.window.Window, "platform_window", self);
    }

    pub inline fn allocator(self: *WindowsWindow) std.mem.Allocator {
        return self.getBase().allocator();
    }

    pub fn init(self: *WindowsWindow, descriptor: app.window.WindowDescriptor) !void {
        try registerClassOnce();
        self.descriptor = descriptor;
        self.modified_state.descriptor = descriptor;
    }

    pub fn build(self: *WindowsWindow) !void {
        self.hwnd = try self.buildWindow();
    }

    pub fn getNativeHandle(self: *const WindowsWindow) app.window.NativeHandle {
        return .{ .wnd = self.hwnd.? };
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

    fn getClientArea(size: [2]u32, styles: Styles) win32.foundation.RECT {
        var rc: win32.foundation.RECT = .{
            .left = 0,
            .top = 0,
            .right = @intCast(size[0]),
            .bottom = @intCast(size[1]),
        };
        _ = win32.ui.windows_and_messaging.AdjustWindowRectEx(
            &rc,
            styles.style,
            FALSE,
            styles.ex,
        );
        return rc;
    }

    fn buildWindow(self: *WindowsWindow) !win32.foundation.HWND {
        const descriptor = self.descriptor;

        var stack_allocator = std.heap.stackFallback(1024, self.allocator());
        var temp_allocator = stack_allocator.get();

        var converted_title = convertToUtf16WithAllocator(
            temp_allocator,
            descriptor.title,
        ) orelse return WindowsError.StringConversionFailed;
        defer temp_allocator.free(converted_title);

        const position = descriptor.position orelse .{
            win32.ui.windows_and_messaging.CW_USEDEFAULT,
            win32.ui.windows_and_messaging.CW_USEDEFAULT,
        };

        const styles = getStyles(&descriptor);
        const rect = getClientArea(descriptor.size, styles);

        const width: i32 = @intCast(rect.right - rect.left);
        const height: i32 = @intCast(rect.bottom - rect.top);

        var hwnd = win32.ui.windows_and_messaging.CreateWindowExW(
            styles.ex,
            class_name,
            converted_title,
            styles.style,
            position[0],
            position[1],
            width,
            height,
            null,
            null,
            try getHInstance(),
            @ptrCast(self),
        ) orelse return WindowsError.HwndCreationFailed;

        if (descriptor.visible) {
            _ = win32.ui.windows_and_messaging.ShowWindow(
                hwnd,
                .SHOW,
            );
        }

        return hwnd;
    }

    pub fn deinit(self: *WindowsWindow) void {
        if (self.hwnd) |hwnd| {
            _ = win32.ui.windows_and_messaging.DestroyWindow(hwnd);
        }
        self.hwnd = null;
    }

    pub fn setTitle(self: *WindowsWindow, title: []const u8) void {
        self.modified_state.descriptor.title = title;
        self.modified_state.title_changed = true;
    }

    pub fn getTitle(self: *const WindowsWindow) []const u8 {
        return self.descriptor.title;
    }

    pub fn setSize(self: *WindowsWindow, size: [2]u32, use_client_area: bool) void {
        self.modified_state.descriptor.size = size;
        self.modified_state.size_changed = true;
        self.modified_state.use_client_area = use_client_area;
    }

    pub fn getContentSize(self: *const WindowsWindow) [2]u32 {
        return self.getSize(true);
    }

    pub fn getSize(self: *const WindowsWindow, use_client_area: bool) [2]u32 {
        if (use_client_area) {
            var rc: win32.foundation.RECT = undefined;
            _ = win32.ui.windows_and_messaging.GetClientRect(
                self.hwnd.?,
                &rc,
            );
            return .{
                @intCast(rc.right - rc.left),
                @intCast(rc.bottom - rc.top),
            };
        } else {
            var rc: win32.foundation.RECT = undefined;
            _ = win32.ui.windows_and_messaging.GetWindowRect(
                self.hwnd.?,
                &rc,
            );
            return .{
                @intCast(rc.right - rc.left),
                @intCast(rc.bottom - rc.top),
            };
        }
    }

    pub fn setPosition(self: *WindowsWindow, position: [2]i32) void {
        self.modified_state.descriptor.position = position;
    }

    pub fn getPosition(self: *const WindowsWindow) ?[2]i32 {
        return self.descriptor.position;
    }

    pub fn setVisible(self: *WindowsWindow, should_show: bool) void {
        self.modified_state.descriptor.visible = should_show;
    }

    pub fn isVisible(self: *const WindowsWindow) bool {
        return self.descriptor.visible;
    }

    pub fn setFullscreenMode(self: *WindowsWindow, mode: app.window.FullscreenMode) void {
        self.modified_state.descriptor.fullscreen_mode = mode;
    }

    pub fn getFullscreenMode(self: *const WindowsWindow) app.window.FullscreenMode {
        return self.descriptor.fullscreen_mode;
    }

    pub fn shouldClose(self: *const WindowsWindow) bool {
        return self.should_close;
    }

    pub fn setShouldClose(self: *WindowsWindow, should_close: bool) void {
        self.should_close = should_close;
    }

    pub fn isFocused(self: *const WindowsWindow) bool {
        return self.focused;
    }

    fn updateStyle(self: *WindowsWindow) void {
        var current_style = win32.ui.windows_and_messaging.GetWindowLongW(
            self.hwnd,
            ._STYLE,
        );
        var styles = getStyles(&self.descriptor);
        current_style &= ~@intFromEnum(Styles.mask);
        current_style = @bitCast(@intFromEnum(util.orEnum(
            Styles.ws,
            .{ current_style, styles.style },
        )));
        _ = win32.ui.windows_and_messaging.SetWindowLongW(
            self.hwnd,
            ._STYLE,
            current_style,
        );
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
        const mask: ws = util.orEnum(ws, .{
            fullscreen,
            borderless,
            normal,
            resizable,
        });
    };

    fn getStyles(descriptor: *const app.window.WindowDescriptor) Styles {
        const ws = win32.ui.windows_and_messaging.WINDOW_STYLE;
        const wexs = win32.ui.windows_and_messaging.WINDOW_EX_STYLE;
        var styles: Styles = .{
            .style = ws.initFlags(.{}),
            .ex = wexs.initFlags(.{}),
        };
        if (descriptor.is_popup) {
            styles.style = util.orEnum(ws, .{ styles.style, .POPUP });
        } else if (descriptor.fullscreen_mode == .fullscreen) {
            styles.style = util.orEnum(ws, .{ styles.style, Styles.fullscreen });
        } else {
            if (descriptor.borderless) {
                styles.style = util.orEnum(ws, .{ styles.style, Styles.borderless_windowed });
            } else {
                styles.style = util.orEnum(ws, .{ styles.style, Styles.normal });
            }

            if (descriptor.resizable) {
                if (!descriptor.borderless) {
                    styles.style = util.orEnum(ws, .{ styles.style, Styles.resizable });
                }
            }

            if (descriptor.open_minimised) {
                styles.style = util.orEnum(ws, .{ styles.style, .MINIMIZE });
            }
        }

        if (descriptor.is_popup) {
            styles.ex = util.orEnum(wexs, .{ styles.ex, .TOOLWINDOW, .NOACTIVATE });
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
        wnd: ?win32.foundation.HWND,
        msg: std.os.windows.UINT,
        wparam: std.os.windows.WPARAM,
        lparam: std.os.windows.LPARAM,
    ) callconv(std.os.windows.WINAPI) std.os.windows.LRESULT {
        var window: *WindowsWindow = window: {
            var window_opt: ?*WindowsWindow = @ptrFromInt(
                @as(usize, @bitCast(win32.ui.windows_and_messaging.GetWindowLongPtrW(
                    wnd,
                    .P_USERDATA,
                ))),
            );
            if (msg == win32.ui.windows_and_messaging.WM_NCCREATE and window_opt == null) {
                const createstruct: *win32.ui.windows_and_messaging.CREATESTRUCTW = @ptrFromInt(
                    @as(usize, @bitCast(lparam)),
                );
                const initdata: ?*WindowsWindow = @alignCast(@ptrCast(
                    createstruct.lpCreateParams,
                ));
                if (initdata == null) {
                    return 0;
                }
                initdata.?.hwnd = wnd;
                _ = win32.ui.windows_and_messaging.SetWindowLongPtrW(
                    wnd,
                    .P_USERDATA,
                    @as(
                        std.os.windows.LONG_PTR,
                        @intCast(@intFromPtr(initdata)),
                    ),
                );
                window_opt = initdata;
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
            },
            win32.ui.windows_and_messaging.WM_KEYDOWN => {
                if (wparam == @intFromEnum(win32.ui.input.keyboard_and_mouse.VIRTUAL_KEY.F)) {
                    window.setFullscreenMode(if (window.descriptor.fullscreen_mode == .windowed) .fullscreen else .windowed);
                }
            },
            win32.ui.windows_and_messaging.WM_MOVE => {
                const x: i32 = @intCast(LOWORD(@bitCast(lparam)));
                const y: i32 = @intCast(HIWORD(@bitCast(lparam)));
                window.modified_state.descriptor.position = .{ x, y };
                window.descriptor.position = .{ x, y };
            },
            win32.ui.windows_and_messaging.WM_SIZE => {
                const width = LOWORD(@bitCast(lparam));
                const height = HIWORD(@bitCast(lparam));
                window.modified_state.descriptor.size = .{ width, height };
                window.descriptor.size = .{ width, height };
            },
            else => {},
        }

        // updaters
        window.update() catch {
            std.debug.print("Failed to update window\n", .{});
        };

        window.getBase().application.input.platform_input.windowProc(
            window,
            msg,
            wparam,
            lparam,
        );

        return win32.ui.windows_and_messaging.DefWindowProcW(wnd, msg, wparam, lparam);
    }

    pub fn update(self: *WindowsWindow) !void {
        try self.updateTitle();
        try self.updateVisible();
        try self.updateSizeAndPosition();
        try self.updateFullscreen();
    }

    fn updateSizeAndPosition(self: *WindowsWindow) !void {
        const descriptor = self.modified_state.descriptor;

        const size_changed = self.modified_state.size_changed;
        const position_changed = blk: {
            const new_position = descriptor.position;
            const old_position = self.descriptor.position;
            if (new_position == null) break :blk false;
            if (old_position == null) break :blk true;

            break :blk new_position.?[0] != old_position.?[0] or
                new_position.?[1] != old_position.?[1];
        };

        if (!size_changed and !position_changed) {
            return;
        }

        var size = descriptor.size;
        if (self.modified_state.use_client_area) {
            var rc = getClientArea(size, getStyles(&descriptor));
            size = .{
                @intCast(rc.right - rc.left),
                @intCast(rc.bottom - rc.top),
            };
        }
        const position = descriptor.position orelse .{
            win32.ui.windows_and_messaging.CW_USEDEFAULT,
            win32.ui.windows_and_messaging.CW_USEDEFAULT,
        };

        var flags: win32.ui.windows_and_messaging.SET_WINDOW_POS_FLAGS = .NOZORDER;
        if (!size_changed) {
            flags = util.orEnum(win32.ui.windows_and_messaging.SET_WINDOW_POS_FLAGS, .{
                flags,
                .NOSIZE,
            });
        } else {
            self.modified_state.descriptor.size = size;
            self.descriptor.size = size;
            self.modified_state.size_changed = false;
        }
        if (!position_changed) {
            flags = util.orEnum(win32.ui.windows_and_messaging.SET_WINDOW_POS_FLAGS, .{
                flags,
                .NOMOVE,
            });
        }
        {
            self.descriptor.position = descriptor.position;
        }

        _ = win32.ui.windows_and_messaging.SetWindowPos(
            self.hwnd,
            null,
            position[0],
            position[1],
            @intCast(size[0]),
            @intCast(size[1]),
            flags,
        );
    }

    const HWND_TOP: ?win32.foundation.HWND = null;
    fn updateFullscreen(
        self: *WindowsWindow,
    ) !void {
        const mode = self.modified_state.descriptor.fullscreen_mode;
        if (mode == self.descriptor.fullscreen_mode) {
            return;
        }
        const previous_mode = self.descriptor.fullscreen_mode;
        self.descriptor.fullscreen_mode = mode;
        self.updateStyle();

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

            self.setPosition(.{ mi.rcMonitor.left, mi.rcMonitor.top });
            self.setSize(.{
                @intCast(mi.rcMonitor.right - mi.rcMonitor.left),
                @intCast(mi.rcMonitor.bottom - mi.rcMonitor.top),
            }, false);
        }

        if (previous_mode == .fullscreen and mode == .windowed) {
            var normal_rect = self.non_fullscreen_window_placement.rcNormalPosition;
            self.setPosition(.{ normal_rect.left, normal_rect.top });
            self.setSize(.{
                @intCast(normal_rect.right - normal_rect.left),
                @intCast(normal_rect.bottom - normal_rect.top),
            }, false);
        }
    }

    fn updateTitle(self: *WindowsWindow) !void {
        if (self.modified_state.title_changed) {
            self.modified_state.title_changed = false;

            var stack_allocator = std.heap.stackFallback(1024, self.allocator());
            var temp_allocator = stack_allocator.get();

            var converted_title = convertToUtf16WithAllocator(
                temp_allocator,
                self.modified_state.descriptor.title,
            ) orelse return WindowsError.StringConversionFailed;
            defer temp_allocator.free(converted_title);

            _ = win32.ui.windows_and_messaging.SetWindowTextW(
                self.hwnd,
                converted_title,
            );
        }
    }

    fn updateVisible(self: *WindowsWindow) !void {
        if (self.modified_state.descriptor.visible != self.descriptor.visible) {
            self.descriptor.visible = self.modified_state.descriptor.visible;
            _ = win32.ui.windows_and_messaging.ShowWindow(
                self.hwnd,
                if (self.descriptor.visible) .SHOW else .HIDE,
            );
        }
    }
};

pub fn getHInstance() !win32.foundation.HINSTANCE {
    var module = win32.system.library_loader.GetModuleHandleW(null);
    return module;
}

pub fn convertToUtf16WithAllocator(
    al: std.mem.Allocator,
    str: []const u8,
) ?[:0]const u16 {
    var converted = std.unicode.utf8ToUtf16LeWithNull(
        al,
        str,
    ) catch return null;
    return converted;
}

pub fn convertToUtf8WithAllocator(
    al: std.mem.Allocator,
    str: []const u16,
) ?[]const u8 {
    var converted = std.unicode.utf16leToUtf8Alloc(
        al,
        str,
    ) catch return null;
    return converted;
}

pub fn messageBox(
    allocator: std.mem.Allocator,
    title: []const u8,
    comptime fmt: []const u8,
    args: anytype,
    style: win32.ui.windows_and_messaging.MESSAGEBOX_STYLE,
) void {
    var stack_allocator = std.heap.stackFallback(
        2048,
        allocator,
    );
    var temp_allocator = stack_allocator.get();

    var message = std.fmt.bufPrint(
        temp_allocator.alloc(u8, 512) catch unreachable,
        fmt,
        args,
    ) catch unreachable;

    var converted_title = std.unicode.utf8ToUtf16LeWithNull(
        temp_allocator,
        title,
    ) catch return;
    defer temp_allocator.free(converted_title);
    var converted_message = std.unicode.utf8ToUtf16LeWithNull(
        temp_allocator,
        message,
    ) catch return;
    defer temp_allocator.free(converted_message);
    _ = win32.ui.windows_and_messaging.MessageBoxW(
        null,
        converted_message,
        converted_title,
        style,
    );
}

pub fn reportError(
    allocator: std.mem.Allocator,
) void {
    var err = win32.foundation.GetLastError();
    messageBox(
        allocator,
        "Fatal error",
        "Program failed with error code\n{}",
        .{err},
        win32.ui.windows_and_messaging.MESSAGEBOX_STYLE.initFlags(.{
            .OK = 1,
        }),
    );
    std.os.exit(1);
}

/// returns true if the error was reported
pub fn reportHResultError(
    allocator: std.mem.Allocator,
    hr: std.os.windows.HRESULT,
    comptime title: []const u8,
) bool {
    if (winapizig.FAILED(hr)) {
        std.log.err("Failed with: {}", .{hr});
        messageBox(
            allocator,
            title,
            "Error: {}",
            .{hr},
            win32.ui.windows_and_messaging.MESSAGEBOX_STYLE.initFlags(.{
                .OK = 1,
            }),
        );
        return true;
    }
    return false;
}

const WindowsInput = struct {
    mouse_button_swap: bool = false,
    last_pointer_update: win32.foundation.LPARAM = 0,

    // mouse
    mouse_capture_count: u32 = 0,
    mouse_button_flags: win32.foundation.WPARAM = 0,

    fn getBase(self: *WindowsInput) *app.input.Input {
        return @fieldParentPtr(app.input.Input, "platform_input", self);
    }

    pub inline fn allocator(self: *WindowsInput) std.mem.Allocator {
        return self.getBase().allocator;
    }

    pub fn init(self: *WindowsInput) WindowsError!void {
        var hr: std.os.windows.HRESULT = 0;
        _ = hr;

        var stack_allocator = std.heap.stackFallback(
            1024,
            self.allocator(),
        );
        _ = stack_allocator;

        self.mouse_button_swap = win32.ui.windows_and_messaging.GetSystemMetrics(
            .SWAPBUTTON,
        ) != 0;

        // if (winapizig.FAILED(gdk.GameInputCreate(&self.game_input))) {
        //     reportError(self.allocator());
        // }
    }

    pub fn deinit(self: *WindowsInput) void {
        _ = self;
    }

    fn pushEvent(self: *WindowsInput, iobj: app.input.InputObject) !void {
        try self.getBase().addEvent(iobj, null);
    }

    fn loadRawInput(self: *WindowsInput, wnd: win32.foundation.HWND) void {
        var mouse_device = win32.ui.input.RAWINPUTDEVICE{
            .usUsagePage = win32.devices.human_interface_device.HID_USAGE_PAGE_GENERIC,
            .usUsage = win32.devices.human_interface_device.HID_USAGE_GENERIC_MOUSE,
            .dwFlags = .INPUTSINK,
            .hwndTarget = wnd,
        };
        var res = win32.ui.input.RegisterRawInputDevices(
            @ptrCast(&mouse_device),
            1,
            @sizeOf(win32.ui.input.RAWINPUTDEVICE),
        );
        if (res == FALSE) {
            reportError(self.allocator());
        }
    }

    pub fn process(self: *WindowsInput) void {
        _ = self;
    }

    fn getMouseRelativePosition(wnd: win32.foundation.HWND) [2]i32 {
        var p: win32.foundation.POINT = undefined;
        _ = win32.ui.windows_and_messaging.GetCursorPos(&p);
        _ = win32.graphics.gdi.ScreenToClient(
            wnd,
            &p,
        );
        return .{ p.x, p.y };
    }

    const MouseEventSource = enum {
        unknown,
        mouse,
        touch,
        pen,
    };

    fn recentMouseEventSource() MouseEventSource {
        const MI_WP_SIGNATURE = 0xFF515700;
        const MI_WP_SIGNATURE_MASK = 0xFFFFFF00;

        var extra_info = win32.ui.windows_and_messaging.GetMessageExtraInfo();
        if ((extra_info & MI_WP_SIGNATURE_MASK) == MI_WP_SIGNATURE) {
            if ((extra_info & 0x80) != 0) {
                return .touch;
            }
            return .pen;
        }
        return .mouse;
    }

    const WM_MOUSELEAVE = @as(u32, 675);

    fn captureInput(self: *WindowsInput, wnd: win32.foundation.HWND) void {
        self.mouse_capture_count += 1;
        if (self.mouse_capture_count == 1) {
            _ = win32.ui.input.keyboard_and_mouse.SetCapture(wnd);
        }
    }

    fn releaseInput(self: *WindowsInput) void {
        if (self.mouse_capture_count == 0) return;
        self.mouse_capture_count -= 1;
        if (self.mouse_capture_count == 0) {
            _ = win32.ui.input.keyboard_and_mouse.ReleaseCapture();
        }
    }

    fn setWindowFocus(self: *WindowsInput, window: *WindowsWindow, focused: bool) void {
        if (focused == window.focused) {
            return;
        }
        window.focused = focused;

        var iobj = app.input.InputObject{
            .type = .focus,
            .window = window.getBase(),
            .input_state = if (focused) .begin else .end,
            .data = .focus,
        };
        self.pushEvent(iobj) catch {};
    }

    const win32_update_timer_id: usize = 1;

    pub fn windowProc(
        self: *WindowsInput,
        window: *WindowsWindow,
        msg: std.os.windows.UINT,
        wparam: std.os.windows.WPARAM,
        lparam: std.os.windows.LPARAM,
    ) void {
        switch (msg) {
            win32.ui.windows_and_messaging.WM_CREATE => {
                self.loadRawInput(window.hwnd.?);
            },
            win32.ui.windows_and_messaging.WM_NCACTIVATE => {
                self.setWindowFocus(window, wparam == FALSE);
            },
            win32.ui.windows_and_messaging.WM_ACTIVATE => {
                self.setWindowFocus(
                    window,
                    LOWORD(@intCast(wparam)) != win32.ui.windows_and_messaging.WA_INACTIVE,
                );
            },
            win32.ui.windows_and_messaging.WM_SIZE => {
                const width = LOWORD(@bitCast(lparam));
                const height = HIWORD(@bitCast(lparam));

                var iobj = app.input.InputObject{
                    .type = .resize,
                    .window = window.getBase(),
                    .input_state = .change,
                    .data = .{ .resize = .{ width, height } },
                };

                self.pushEvent(iobj) catch {};
            },
            win32.ui.windows_and_messaging.WM_SETFOCUS => {
                self.setWindowFocus(window, true);
            },
            win32.ui.windows_and_messaging.WM_KILLFOCUS, win32.ui.windows_and_messaging.WM_ENTERIDLE => {
                // prevents app from thinking buttons are still down when the window loses focus
                self.processMouseButtonWparam(window, 0);
                self.setWindowFocus(window, false);
            },
            win32.ui.windows_and_messaging.WM_POINTERUPDATE => {
                self.last_pointer_update = lparam;
            },

            win32.ui.windows_and_messaging.WM_LBUTTONUP,
            win32.ui.windows_and_messaging.WM_RBUTTONUP,
            win32.ui.windows_and_messaging.WM_MBUTTONUP,
            win32.ui.windows_and_messaging.WM_XBUTTONUP,
            win32.ui.windows_and_messaging.WM_LBUTTONDOWN,
            win32.ui.windows_and_messaging.WM_LBUTTONDBLCLK,
            win32.ui.windows_and_messaging.WM_RBUTTONDOWN,
            win32.ui.windows_and_messaging.WM_RBUTTONDBLCLK,
            win32.ui.windows_and_messaging.WM_MBUTTONDOWN,
            win32.ui.windows_and_messaging.WM_MBUTTONDBLCLK,
            win32.ui.windows_and_messaging.WM_XBUTTONDOWN,
            win32.ui.windows_and_messaging.WM_XBUTTONDBLCLK,
            => {
                if (recentMouseEventSource() != .touch and lparam != self.last_pointer_update) {
                    self.processMouseButtonWparam(window, wparam);
                }
            },

            win32.ui.windows_and_messaging.WM_KEYDOWN => self.postKeyEvent(window, wparam, lparam, true),
            win32.ui.windows_and_messaging.WM_KEYUP => self.postKeyEvent(window, wparam, lparam, false),
            win32.ui.windows_and_messaging.WM_CHAR => {
                var iobj = app.input.InputObject{
                    .type = .textinput,
                    .window = window.getBase(),
                    .input_state = .begin,
                    .data = .{ .textinput = .{ .short = @truncate(wparam) } },
                };
                self.pushEvent(iobj) catch {};
            },

            win32.ui.windows_and_messaging.WM_MOUSEWHEEL => {
                var iobj = app.input.InputObject{
                    .type = .mousewheel,
                    .window = window.getBase(),
                    .input_state = .begin,
                    .data = .mousewheel,
                    .delta = math.f32x4(
                        0,
                        @floatFromInt(HIWORD(@intCast(wparam)) / win32.ui.windows_and_messaging.WHEEL_DELTA),
                        0,
                        0,
                    ),
                };
                self.pushEvent(iobj) catch {};
            },
            win32.ui.windows_and_messaging.WM_MOUSEMOVE => self.postLocalMouseMotion(window, lparam),

            win32.ui.windows_and_messaging.WM_ENTERSIZEMOVE => {
                _ = win32.ui.windows_and_messaging.SetTimer(
                    window.hwnd,
                    win32_update_timer_id,
                    win32.ui.windows_and_messaging.USER_TIMER_MINIMUM,
                    null,
                );
            },

            win32.ui.windows_and_messaging.WM_EXITSIZEMOVE => {
                _ = win32.ui.windows_and_messaging.KillTimer(
                    window.hwnd,
                    win32_update_timer_id,
                );
            },

            win32.ui.windows_and_messaging.WM_SHOWWINDOW => {
                if (wparam == win32.foundation.TRUE) {
                    _ = win32.ui.windows_and_messaging.KillTimer(
                        window.hwnd,
                        win32_update_timer_id,
                    );
                } else {
                    _ = win32.ui.windows_and_messaging.SetTimer(
                        window.hwnd,
                        win32_update_timer_id,
                        win32.ui.windows_and_messaging.USER_TIMER_MINIMUM,
                        null,
                    );
                }
            },

            win32.ui.windows_and_messaging.WM_TIMER => {
                if (wparam == win32_update_timer_id) {
                    if (self.getBase().frame_update_callback) |cb| {
                        cb(window.getBase());
                    }
                }
            },

            win32.ui.windows_and_messaging.WM_INPUT => {
                self.postGlobalMouseMotion(window, lparam);
            },

            else => {},
        }
    }

    fn postKeyEvent(self: *WindowsInput, wnd: *WindowsWindow, wparam: std.os.windows.WPARAM, lparam: std.os.windows.LPARAM, down: bool) void {
        var iobj = app.input.InputObject{
            .type = .keyboard,
            .window = wnd.getBase(),
            .input_state = if (down) .begin else .end,
            .data = .{
                .keyboard = .{
                    .down = down,
                    .keycode = windowsToKeycode(lparam, wparam),
                    .scancode = @truncate(@as(usize, @bitCast(lparam >> 16)) & 0xff),
                },
            },
        };
        self.pushEvent(iobj) catch {};
    }

    fn processIndividualMouseButtonWparam(
        self: *WindowsInput,
        wnd: *WindowsWindow,
        wparam: win32.foundation.WPARAM,
        button_index: usize,
        button_flag: win32.system.system_services.MODIFIERKEYS_FLAGS,
    ) void {
        var use_button_index = button_index;

        if (self.mouse_button_swap) {
            if (use_button_index == 0) {
                use_button_index = 1;
            } else if (use_button_index == 1) {
                use_button_index = 0;
            }
        }

        var old_state = self.getBase().mouse_state.buttons[use_button_index];
        var new_state = ((wparam & @as(usize, @intFromEnum(button_flag))) != 0);
        var should_update = (old_state != new_state);

        if (should_update) {
            self.getBase().mouse_state.buttons[use_button_index] = new_state;

            if (new_state) {
                self.captureInput(wnd.hwnd.?);
            } else {
                self.releaseInput();
            }

            var iobj = app.input.InputObject{
                .type = .mousebutton,
                .window = wnd.getBase(),
                .input_state = if (new_state) .begin else .end,
                .data = .{ .mousebutton = @truncate(use_button_index) },
            };
            self.pushEvent(iobj) catch {};
        }
    }

    fn processMouseButtonWparam(self: *WindowsInput, wnd: *WindowsWindow, wparam: win32.foundation.WPARAM) void {
        if (self.mouse_button_flags != wparam) {
            self.processIndividualMouseButtonWparam(
                wnd,
                wparam,
                0,
                .LBUTTON,
            );
            self.processIndividualMouseButtonWparam(
                wnd,
                wparam,
                1,
                .RBUTTON,
            );
            self.processIndividualMouseButtonWparam(
                wnd,
                wparam,
                2,
                .MBUTTON,
            );
            self.processIndividualMouseButtonWparam(
                wnd,
                wparam,
                3,
                .XBUTTON1,
            );
            self.processIndividualMouseButtonWparam(
                wnd,
                wparam,
                4,
                .XBUTTON2,
            );

            self.mouse_button_flags = wparam;
        }
    }

    fn postLocalMouseMotion(self: *WindowsInput, wnd: *WindowsWindow, lparam: std.os.windows.LPARAM) void {
        const x: i32 = GET_X_LPARAM(lparam);
        const y: i32 = GET_Y_LPARAM(lparam);

        const last_pos = self.getBase().mouse_state.position;

        var iobj = app.input.InputObject{
            .type = .mousemove,
            .window = wnd.getBase(),
            .input_state = .change,
            .data = .mousemove,
            .position = math.f32x4(@floatFromInt(x), @floatFromInt(y), 0, 0),
            .delta = math.f32x4(@floatFromInt(x - last_pos[0]), @floatFromInt(y - last_pos[1]), 0, 0),
        };

        const converted_pos = math.vecToArr2(iobj.position);
        self.getBase().mouse_state.position = .{ @intFromFloat(converted_pos[0]), @intFromFloat(converted_pos[1]) };
        self.pushEvent(iobj) catch {};
    }

    fn postGlobalMouseMotion(self: *WindowsInput, wnd: *WindowsWindow, lparam: std.os.windows.LPARAM) void {
        if (!self.getBase().has_focus) {
            return;
        }

        var raw: win32.ui.input.RAWINPUT = undefined;
        var raw_size: std.os.windows.UINT = @sizeOf(win32.ui.input.RAWINPUT);
        _ = win32.ui.input.GetRawInputData(
            @ptrFromInt(@as(usize, @bitCast(lparam))),
            .INPUT,
            &raw,
            &raw_size,
            @sizeOf(win32.ui.input.RAWINPUTHEADER),
        );

        if (raw.header.dwType == @intFromEnum(win32.ui.input.RIM_TYPEMOUSE)) {
            const mouse = raw.data.mouse;
            if (mouse.usFlags == win32.devices.human_interface_device.MOUSE_MOVE_RELATIVE) {
                const dx = mouse.lLastX;
                const dy = mouse.lLastY;

                const new_pos = getMouseRelativePosition(wnd);

                var iobj = app.input.InputObject{
                    .type = .mousemove,
                    .window = wnd.getBase(),
                    .input_state = .change,
                    .data = .mousemove,
                    .position = math.f32x4(@floatFromInt(new_pos[0]), @floatFromInt(new_pos[1]), 0, 1),
                    .delta = math.f32x4(
                        @floatFromInt(dx),
                        @floatFromInt(dy),
                        0,
                        0,
                    ),
                };

                self.getBase().mouse_state.position = new_pos;
                self.pushEvent(iobj) catch {};
            }
        }
    }

    fn windowsToKeycode(lparam: std.os.windows.LPARAM, wparam: std.os.windows.WPARAM) app.input.KeyCode {
        const scancode = (lparam >> 16) & 0xFF;
        const extended = (lparam & (1 << 24)) != 0;

        var code = vkeyToKeyCode(wparam);

        if (code == .unknown and scancode <= 127) {
            code = keycode_map_table[@bitCast(scancode)];
            code = blk: {
                if (extended) {
                    switch (code) {
                        .@"return" => break :blk .kp_enter,
                        .lalt => break :blk .ralt,
                        .lctrl => break :blk .rctrl,
                        .slash => break :blk .kp_divide,
                        .capslock => break :blk .kp_plus,
                        else => {},
                    }
                } else {
                    switch (code) {
                        .home => break :blk .kp7,
                        .up => break :blk .kp8,
                        .pageup => break :blk .kp9,
                        .left => break :blk .kp4,
                        .right => break :blk .kp6,
                        .end => break :blk .kp1,
                        .down => break :blk .kp2,
                        .pagedown => break :blk .kp3,
                        .insert => break :blk .kp0,
                        .delete => break :blk .kp_period,
                        .print => break :blk .kp_multiply,
                        else => {},
                    }
                }

                break :blk code;
            };
        }

        return code;
    }

    fn vkeyToKeyCode(wparam: std.os.windows.WPARAM) app.input.KeyCode {
        const VK = win32.ui.input.keyboard_and_mouse.VIRTUAL_KEY;
        return switch (@as(VK, @enumFromInt(wparam))) {
            VK.MODECHANGE => .mode,
            // VK.SELECT => .select,
            // VK.EXECUTE => .run,
            VK.HELP => .help,
            VK.PAUSE => .pause,
            // VK.NUMLOCK => .numlock,

            VK.F13 => .f13,
            VK.F14 => .f14,
            VK.F15 => .f15,
            // VK.F16 => .f16,
            // VK.F17 => .f17,
            // VK.F18 => .f18,
            // VK.F19 => .f19,
            // VK.F20 => .f20,
            // VK.F21 => .f21,
            // VK.F22 => .f22,
            // VK.F23 => .f23,
            // VK.F24 => .f24,

            VK.OEM_NEC_EQUAL => .kp_equals,
            // VK.BROWSER_BACK => .ac_back,
            // VK.BROWSER_FORWARD => .ac_forward,
            // VK.BROWSER_REFRESH => .ac_refresh,
            // VK.BROWSER_STOP => .ac_stop,
            // VK.BROWSER_SEARCH => .ac_search,
            // VK.BROWSER_FAVORITES => .ac_bookmarks,
            // VK.BROWSER_HOME => .ac_home,
            // VK.VOLUME_MUTE => .audiomute,
            // VK.VOLUME_DOWN => .volumedown,
            // VK.VOLUME_UP => .volumeup,

            // VK.MEDIA_NEXT_TRACK => .audionext,
            // VK.MEDIA_PREV_TRACK => .audioprev,
            // VK.MEDIA_STOP => .audiostop,
            // VK.MEDIA_PLAY_PAUSE => .audioplay,
            // VK.LAUNCH_MAIL => .mail,
            // VK.LAUNCH_MEDIA_SELECT => .media,

            // VK.OEM_102 => .nonusbackslash,

            // VK.ATTN => .sysreq,
            // VK.CRSEL => .crsel,
            // VK.EXSEL => .exsel,
            VK.OEM_CLEAR => .clear,

            // VK.LAUNCH_APP1 => .app1,
            // VK.LAUNCH_APP2 => .app2,

            else => .unknown,
        };
    }

    const keycode_map_table = [_]app.input.KeyCode{
        .unknown,
        .escape,
        .@"1",
        .@"2",
        .@"3",
        .@"4",
        .@"5",
        .@"6",
        .@"7",
        .@"8",
        .@"9",
        .@"0",
        .minus,
        .equals,
        .backspace,
        .tab,
        .q,
        .w,
        .e,
        .r,
        .t,
        .y,
        .u,
        .i,
        .o,
        .p,
        .leftbracket,
        .rightbracket,
        .@"return",
        .lctrl,
        .a,
        .s,
        .d,
        .f,
        .g,
        .h,
        .j,
        .k,
        .l,
        .semicolon,
        .quote,
        .backquote,
        .lshift,
        .backslash,
        .z,
        .x,
        .c,
        .v,
        .b,
        .n,
        .m,
        .comma,
        .period,
        .slash,
        .rshift,
        .print,
        .lalt,
        .space,
        .capslock,
        .f1,
        .f2,
        .f3,
        .f4,
        .f5,
        .f6,
        .f7,
        .f8,
        .f9,
        .f10,
        .unknown, // .numlockclear,
        .unknown, // .scrolllock,
        .home,
        .up,
        .pageup,
        .kp_minus,
        .left,
        .kp5,
        .right,
        .kp_plus,
        .end,
        .down,
        .pagedown,
        .insert,
        .delete,
        .unknown,
        .unknown,
        .unknown, // .nonusbackslash,
        .f11,
        .f12,
        .pause,
        .unknown,
        .unknown, // .lgui,
        .unknown, // .rgui,
        .unknown, // .application,
        .unknown,
        .unknown,
        .unknown,
        .unknown,
        .unknown,
        .unknown,
        .f13,
        .f14,
        .f15,
        .unknown, // .f16,
        .unknown, // .f17,
        .unknown, // .f18,
        .unknown, // .f19,
        .unknown,
        .unknown,
        .unknown,
        .unknown,
        .unknown,
        .unknown, //.international2,
        .unknown,
        .unknown,
        .unknown, //.international1,
        .unknown,
        .unknown,
        .unknown,
        .unknown,
        .unknown,
        .unknown, //.international4,
        .unknown,
        .unknown, //.international5,
        .unknown,
        .unknown, //.international3,
        .unknown,
        .unknown,
    };
};

pub inline fn LOWORD(l: usize) std.os.windows.WORD {
    return std.zig.c_translation.cast(
        std.os.windows.WORD,
        std.zig.c_translation.cast(
            std.os.windows.DWORD_PTR,
            l,
        ) & 0xffff,
    );
}
pub inline fn HIWORD(l: usize) std.os.windows.WORD {
    return std.zig.c_translation.cast(
        std.os.windows.WORD,
        (std.zig.c_translation.cast(
            std.os.windows.DWORD_PTR,
            l,
        ) >> @as(c_int, 16)) & 0xffff,
    );
}
pub inline fn LOBYTE(w: anytype) std.os.windows.BYTE {
    return std.zig.c_translation.cast(std.os.windows.BYTE, std.zig.c_translation.cast(
        std.os.windows.DWORD_PTR,
        w,
    ) & 0xff);
}
pub inline fn HIBYTE(w: anytype) std.os.windows.BYTE {
    return std.zig.c_translation.cast(std.os.windows.BYTE, (std.zig.c_translation.cast(
        std.os.windows.DWORD_PTR,
        w,
    ) >> @as(c_int, 8)) & 0xff);
}
pub inline fn GET_X_LPARAM(lp: isize) c_int {
    return std.zig.c_translation.cast(c_int, std.zig.c_translation.cast(
        c_short,
        LOWORD(@bitCast(lp)),
    ));
}
pub inline fn GET_Y_LPARAM(lp: isize) c_int {
    return std.zig.c_translation.cast(c_int, std.zig.c_translation.cast(
        c_short,
        HIWORD(@bitCast(lp)),
    ));
}

// Taken from https://github.com/microsoft/Windows-class-samples
// Transpiled into zig
// The MIT License (MIT)

// Copyright (c) Microsoft Corporation

// Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

// Portions of this repo are provided under the SIL Open Font License.
// See the LICENSE file in individual samples for additional details.

const RegKey = struct {
    const HKEY = win32.system.registry.HKEY;
    handle: ?HKEY = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) RegKey {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RegKey) void {
        self.close();
    }

    pub fn create(
        self: *RegKey,
        key_present: ?HKEY,
        key_name: []const u8,
        class: []const u8,
        options: ?win32.system.registry.REG_OPEN_CREATE_OPTIONS,
        desired: ?win32.system.registry.REG_SAM_FLAGS,
        security_attributes: ?*win32.security.SECURITY_ATTRIBUTES,
        out_disposition: ?*win32.system.registry.REG_CREATE_KEY_DISPOSITION,
    ) WindowsError!win32.foundation.WIN32_ERROR {
        var use_options = options orelse win32.system.registry.REG_OPEN_CREATE_OPTIONS.initFlags(.{
            .RESERVED = 1, // NON_VOLATILE
        });
        var use_desired = desired orelse win32.system.registry.REG_SAM_FLAGS.initFlags(.{
            .READ = 1,
            .WRITE = 1,
        });

        var disposition: std.os.windows.DWORD = 0;
        var key_handle: ?HKEY = null;

        var stack_allocator = std.heap.stackFallback(
            1024,
            self.allocator,
        );
        var temp_allocator = stack_allocator.get();

        var res: win32.foundation.WIN32_ERROR = @enumFromInt(win32.system.registry.RegCreateKeyExW(
            key_present,
            std.unicode.utf8ToUtf16LeWithNull(
                temp_allocator,
                key_name,
            ) catch return WindowsError.StringConversionFailed,
            0,
            std.unicode.utf8ToUtf16LeWithNull(
                temp_allocator,
                class,
            ) catch return WindowsError.StringConversionFailed,
            use_options,
            use_desired,
            security_attributes,
            &key_handle,
            &disposition,
        ));
        if (out_disposition) |od| {
            od.* = @intFromEnum(disposition);
        }

        if (res == .NO_ERROR) {
            self.close();
            self.handle = key_handle;
        }

        return res;
    }

    pub fn open(
        self: *RegKey,
        key_parent: *const HKEY,
        key_name: []const u8,
        desired: win32.system.registry.REG_SAM_FLAGS,
    ) WindowsError!win32.foundation.WIN32_ERROR {
        var key_handle: ?HKEY = null;

        var stack_allocator = std.heap.stackFallback(
            1024,
            self.allocator,
        );
        var temp_allocator = stack_allocator.get();

        var res: win32.foundation.WIN32_ERROR = win32.system.registry.RegOpenKeyExW(
            key_parent.*,
            std.unicode.utf8ToUtf16LeWithNull(
                temp_allocator,
                key_name,
            ) catch return WindowsError.StringConversionFailed,
            0,
            desired,
            &key_handle,
        );
        if (res == .NO_ERROR) {
            _ = self.close();
            self.handle = key_handle;
        }
        return res;
    }

    pub fn close(self: *RegKey) win32.foundation.WIN32_ERROR {
        var res: win32.foundation.WIN32_ERROR = .NO_ERROR;
        if (self.handle) |handle| {
            res = win32.system.registry.RegCloseKey(handle);
            self.handle = null;
        }
        return res;
    }

    pub fn deleteSubKey(self: *RegKey, sub_key: []const u8) WindowsError!win32.foundation.WIN32_ERROR {
        var stack_allocator = std.heap.stackFallback(
            1024,
            self.allocator,
        );
        var temp_allocator = stack_allocator.get();

        return @enumFromInt(win32.system.registry.RegDeleteKeyW(
            self.handle,
            std.unicode.utf8ToUtf16LeWithNull(
                temp_allocator,
                sub_key,
            ) catch return WindowsError.StringConversionFailed,
        ));
    }

    pub fn recurseDeleteKey(self: *RegKey, sub_key: []const u8) win32.foundation.WIN32_ERROR {
        var key = RegKey.init(self.allocator);
        var res = key.open(
            self.handle,
            sub_key,
            win32.system.registry.REG_SAM_FLAGS.initFlags(.{
                .READ = 1,
                .WRITE = 1,
            }),
        );
        if (res != .NO_ERROR) {
            return res;
        }

        var time: win32.foundation.FILETIME = .{ .dwLowDateTime = 0, .dwHighDateTime = 0 };
        var sub_key_name: [256]std.os.windows.WCHAR = .{0} ** 256;
        var sub_key_name_len: std.os.windows.DWORD = 256;

        while (win32.system.registry.RegEnumKeyExW(
            key.handle,
            0,
            &sub_key_name,
            &sub_key_name_len,
            null,
            null,
            null,
            &time,
        ) == .NO_ERROR) {
            sub_key_name[sub_key_name.len - 1] = 0;
            res = key.recurseDeleteKey(sub_key_name);
            if (res != .NO_ERROR) {
                return res;
            }
            sub_key_name_len = 256;
        }

        key.close();
        return self.deleteSubKey(sub_key);
    }

    pub fn deleteValue(self: *RegKey, value: []const u8) WindowsError!win32.foundation.WIN32_ERROR {
        var stack_allocator = std.heap.stackFallback(
            1024,
            self.allocator,
        );
        var temp_allocator = stack_allocator.get();

        return @enumFromInt(win32.system.registry.RegDeleteValueW(
            self.handle,
            std.unicode.utf8ToUtf16LeWithNull(
                temp_allocator,
                value,
            ) catch return WindowsError.StringConversionFailed,
        ));
    }

    // outputs into the allocator provided
    // MUST BE FREED
    pub fn queryStringValue(self: *RegKey, value_name: []const u8, max_chars: ?u32) WindowsError![]const u8 {
        var res: win32.foundation.WIN32_ERROR = .NO_ERROR;
        var data_type: win32.system.registry.REG_VALUE_TYPE = .NONE;
        var use_max_chars = max_chars orelse 128;

        var stack_allocator = std.heap.stackFallback(
            2048,
            self.allocator,
        );
        var temp_allocator = stack_allocator.get();

        var data = temp_allocator.alloc(
            std.os.windows.WCHAR,
            use_max_chars,
        ) catch return WindowsError.AllocationFailed;

        res = win32.system.registry.RegQueryValueExW(
            self.handle,
            std.unicode.utf8ToUtf16LeWithNull(
                temp_allocator,
                value_name,
            ) catch return WindowsError.StringConversionFailed,
            null,
            &data_type,
            @ptrCast(data),
            @ptrCast(&use_max_chars),
        );
        if (res != .NO_ERROR) {
            return WindowsError.RegistryError;
        }
        if (data_type != .SZ and data_type != .EXPAND_SZ) {
            return WindowsError.UnexpectedRegistryValueType;
        }

        return std.unicode.utf16leToUtf8Alloc(
            self.allocator,
            data,
        ) catch return WindowsError.StringConversionFailed;
    }

    pub fn setStringValue(
        self: *RegKey,
        value_name: []const u8,
        value: []const u8,
        reg_type: win32.system.registry.REG_VALUE_TYPE,
    ) WindowsError!win32.foundation.WIN32_ERROR {
        var stack_allocator = std.heap.stackFallback(
            1024,
            self.allocator,
        );
        var temp_allocator = stack_allocator.get();

        var value_converted = std.unicode.utf8ToUtf16LeWithNull(
            temp_allocator,
            value,
        ) catch return WindowsError.StringConversionFailed;

        return @enumFromInt(win32.system.registry.RegSetValueExW(
            self.handle,
            std.unicode.utf8ToUtf16LeWithNull(
                temp_allocator,
                value_name,
            ) catch return WindowsError.StringConversionFailed,
            0,
            reg_type,
            @ptrCast(value_converted),
            (value_converted.len + 1) * @sizeOf(std.os.windows.WCHAR),
        ));
    }

    pub fn queryDwordValue(self: *RegKey, value_name: []const u8) WindowsError!u32 {
        var res: win32.foundation.WIN32_ERROR = .NO_ERROR;
        var data_type: win32.system.registry.REG_VALUE_TYPE = .NONE;
        var data: u32 = 0;
        var data_size: std.os.windows.DWORD = @sizeOf(u32);

        var stack_allocator = std.heap.stackFallback(
            1024,
            self.allocator,
        );
        var temp_allocator = stack_allocator.get();

        res = win32.system.registry.RegQueryValueExW(
            self.handle,
            std.unicode.utf8ToUtf16LeWithNull(
                temp_allocator,
                value_name,
            ) catch return WindowsError.StringConversionFailed,
            null,
            &data_type,
            @ptrCast(&data),
            @ptrCast(&data_size),
        );
        if (res != .NO_ERROR) {
            return WindowsError.RegistryError;
        }
        if (data_type != .DWORD) {
            return WindowsError.UnexpectedRegistryValueType;
        }

        return data;
    }

    pub fn setDwordValue(
        self: *RegKey,
        value_name: []const u8,
        value: u32,
    ) WindowsError!win32.foundation.WIN32_ERROR {
        return @enumFromInt(win32.system.registry.RegSetValueExW(
            self.handle,
            std.unicode.utf8ToUtf16LeWithNull(
                self.allocator,
                value_name,
            ) catch return WindowsError.StringConversionFailed,
            0,
            .DWORD,
            @ptrCast(&value),
            @sizeOf(u32),
        ));
    }

    // omitted binary registry keys
};
