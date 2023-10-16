const std = @import("std");

const app = @import("../app.zig");
const math = @import("../../math.zig");
const util = @import("../../util.zig");

const win32 = @import("win32");

pub const Error = WindowsError;
pub const Application = WindowsApplication;
pub const Window = WindowsWindow;
pub const Input = WindowsInput;

const WindowsError = error{
    StringConversionFailed,
    HwndCreationFailed,
    HwndDestroyFailed,
    ClassRegistrationFailed,
    HInstanceNull,
    AllocationFailed,
    UnexpectedRegistryValueType,
    RegistryError,

    MouseCreationFailure,
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
    const class_name = win32.zig.L("app");

    hwnd: ?win32.foundation.HWND = null,

    should_close: bool = false,
    focused: bool = false,
    descriptor: app.window.WindowDescriptor,

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
            return WindowsError.StringConversionFailed;
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

    fn updateStyle(self: *WindowsWindow) void {
        var current_style = win32.ui.windows_and_messaging.GetWindowLongW(
            self.hwnd,
            ._STYLE,
        );
        var styles = self.getStyles();
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

    const HWND_TOP: ?win32.foundation.HWND = null;
    pub fn setFullscreen(
        self: *WindowsWindow,
        mode: app.window.FullscreenMode,
    ) void {
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

            _ = win32.ui.windows_and_messaging.SetWindowPos(
                self.hwnd,
                HWND_TOP,
                mi.rcMonitor.left,
                mi.rcMonitor.top,
                mi.rcMonitor.right - mi.rcMonitor.left,
                mi.rcMonitor.bottom - mi.rcMonitor.top,
                util.orEnum(win32.ui.windows_and_messaging.SET_WINDOW_POS_FLAGS, .{
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
                util.orEnum(win32.ui.windows_and_messaging.SET_WINDOW_POS_FLAGS, .{
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
        const mask: ws = util.orEnum(ws, .{
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
                window.setShouldClose(true);
            },
            win32.ui.windows_and_messaging.WM_KEYDOWN => {
                if (wparam == @intFromEnum(win32.ui.input.keyboard_and_mouse.VK_F)) {
                    window.setFullscreen(if (window.descriptor.fullscreen_mode == .windowed) .fullscreen else .windowed);
                }
            },
            else => {},
        }

        window.getBase().application.input.platform_input.windowProc(window, msg, wparam, lparam);

        return win32.ui.windows_and_messaging.DefWindowProcW(wnd, msg, wparam, lparam);
    }
};

fn getHInstance() !win32.foundation.HINSTANCE {
    var module = win32.system.library_loader.GetModuleHandleW(null);
    return module orelse return WindowsError.HInstanceNull;
}

fn messageBox(
    allocator: std.mem.Allocator,
    title: []const u8,
    message: []const u8,
    style: win32.ui.windows_and_messaging.MESSAGEBOX_STYLE,
) void {
    var stack_allocator = std.heap.stackFallback(
        1024,
        allocator,
    );
    var temp_allocator = stack_allocator.get();
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

const WindowsInput = struct {
    mouse_button_swap: bool = false,
    last_pointer_update: win32.foundation.LPARAM = 0,
    mouse_capture_count: u32 = 0,
    relative_mouse_mode: bool = false,
    relative_mouse_mode_warp: bool = false,
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

        var mouse_key = RegKey.init(stack_allocator.get());
        if (try mouse_key.open(
            &win32.system.registry.HKEY_CURRENT_USER,
            "Control Panel\\Mouse",
            .READ,
        ) == .NO_ERROR) {
            self.mouse_button_swap = blk: {
                var sbs = (mouse_key.queryStringValue(
                    "SwapMouseButtons",
                    256,
                ) catch break :blk false);
                break :blk sbs[0] == '1';
            };
        }
    }

    pub fn deinit(self: *WindowsInput) void {
        _ = self;
    }

    const MouseEventSource = enum {
        unknown,
        mouse,
        touch,
        pen,
    };

    fn mouseEventSource() MouseEventSource {
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

    fn captureMouseButton(self: *WindowsInput, wnd: win32.foundation.HWND) void {
        self.mouse_capture_count += 1;
        if (self.mouse_capture_count == 1) {
            _ = win32.ui.input.keyboard_and_mouse.SetCapture(wnd);
        }
    }

    fn releaseMouseButton(self: *WindowsInput) void {
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
            .input_state = if (focused) .begin else .end,
            .source_type = .focus,
            .specific_data = .{ .focus = window.getBase() },
        };
        self.getBase().addEvent(iobj, null) catch {};
    }

    pub fn windowProc(
        self: *WindowsInput,
        window: *WindowsWindow,
        msg: std.os.windows.UINT,
        wparam: std.os.windows.WPARAM,
        lparam: std.os.windows.LPARAM,
    ) void {
        switch (msg) {
            win32.ui.windows_and_messaging.WM_NCACTIVATE => {
                self.setWindowFocus(window, wparam == win32.zig.FALSE);
            },
            win32.ui.windows_and_messaging.WM_ACTIVATE => {
                self.setWindowFocus(
                    window,
                    loWord(wparam) != win32.ui.windows_and_messaging.WA_INACTIVE,
                );
            },
            win32.ui.windows_and_messaging.WM_SETFOCUS => {
                self.setWindowFocus(window, true);
            },
            win32.ui.windows_and_messaging.WM_KILLFOCUS, win32.ui.windows_and_messaging.WM_ENTERIDLE => {
                self.setWindowFocus(window, false);
            },
            win32.ui.windows_and_messaging.WM_POINTERUPDATE => {
                self.last_pointer_update = lparam;
            },
            win32.ui.windows_and_messaging.WM_MOUSEMOVE => {
                if (!self.relative_mouse_mode or self.relative_mouse_mode_warp) {
                    if (mouseEventSource() != .touch and lparam != self.last_pointer_update) {
                        //TODO(dpi)
                        var x: f32 = @floatFromInt(@as(i16, @bitCast(loWord(lparam))));
                        var y: f32 = @floatFromInt(@as(i16, @bitCast(hiWord(lparam))));
                        var iobj = app.input.InputObject{
                            .type = .mousemove,
                            .input_state = .change,
                            .source_type = .mousemove,
                            .specific_data = .mousemove,
                            .position = math.Vector3f.init(x, y, 0),
                        };
                        self.getBase().addEvent(iobj, null) catch {};
                    }
                }
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
                if (!self.relative_mouse_mode or self.relative_mouse_mode_warp) {
                    if (mouseEventSource() != .touch and lparam != self.last_pointer_update) {
                        self.processMouseButtonWparam(window.hwnd.?, wparam);
                    }
                }
            },

            WM_MOUSELEAVE => {},

            else => {},
        }
    }

    fn processIndividualMouseButtonWparam(
        self: *WindowsInput,
        wnd: win32.foundation.HWND,
        wparam: win32.foundation.WPARAM,
        button_index: usize,
        button_flag: u32,
    ) void {
        var use_button_index = button_index;

        if (self.mouse_button_swap) {
            if (use_button_index == 0) {
                use_button_index = 1;
            } else if (use_button_index == 1) {
                use_button_index = 0;
            }
        }

        var old_state = self.getBase().mouse_buttons[use_button_index];
        var new_state = ((wparam & button_flag) != 0);
        var should_update = (old_state != new_state);

        if (should_update) {
            self.getBase().mouse_buttons[use_button_index] = new_state;

            if (new_state) {
                self.captureMouseButton(wnd);
            } else {
                self.releaseMouseButton();
            }

            var iobj = app.input.InputObject{
                .type = .mousebutton,
                .input_state = if (new_state) .begin else .end,
                .source_type = .mousebutton,
                .specific_data = .{ .mousebutton = @truncate(use_button_index) },
            };
            self.getBase().addEvent(iobj, null) catch {};
        }
    }

    fn processMouseButtonWparam(self: *WindowsInput, wnd: win32.foundation.HWND, wparam: win32.foundation.WPARAM) void {
        if (self.mouse_button_flags != wparam) {
            self.processIndividualMouseButtonWparam(
                wnd,
                wparam,
                0,
                win32.ui.windows_and_messaging.MK_LBUTTON,
            );
            self.processIndividualMouseButtonWparam(
                wnd,
                wparam,
                1,
                win32.ui.windows_and_messaging.MK_RBUTTON,
            );
            self.processIndividualMouseButtonWparam(
                wnd,
                wparam,
                2,
                win32.ui.windows_and_messaging.MK_MBUTTON,
            );
            self.processIndividualMouseButtonWparam(
                wnd,
                wparam,
                3,
                win32.ui.windows_and_messaging.MK_XBUTTON1,
            );
            self.processIndividualMouseButtonWparam(
                wnd,
                wparam,
                4,
                win32.ui.windows_and_messaging.MK_XBUTTON2,
            );

            self.mouse_button_flags = wparam;
        }
    }
};

inline fn loWord(l: anytype) std.os.windows.WORD {
    return @truncate(@as(
        std.os.windows.DWORD,
        @truncate(@as(usize, @bitCast(l))),
    ) & 0xffff);
}

inline fn hiWord(l: anytype) std.os.windows.WORD {
    return @truncate((@as(
        std.os.windows.DWORD,
        @truncate(@as(usize, @bitCast(l))),
    ) >> 16) & 0xffff);
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

        var res: win32.foundation.WIN32_ERROR = @enumFromInt(win32.system.registry.RegOpenKeyExW(
            key_parent.*,
            std.unicode.utf8ToUtf16LeWithNull(
                temp_allocator,
                key_name,
            ) catch return WindowsError.StringConversionFailed,
            0,
            desired,
            &key_handle,
        ));
        if (res == .NO_ERROR) {
            _ = self.close();
            self.handle = key_handle;
        }
        return res;
    }

    pub fn close(self: *RegKey) win32.foundation.WIN32_ERROR {
        var res: win32.foundation.WIN32_ERROR = .NO_ERROR;
        if (self.handle) |handle| {
            res = @enumFromInt(@as(u32, @bitCast(win32.system.registry.RegCloseKey(handle))));
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

        res = @enumFromInt(win32.system.registry.RegQueryValueExW(
            self.handle,
            std.unicode.utf8ToUtf16LeWithNull(
                temp_allocator,
                value_name,
            ) catch return WindowsError.StringConversionFailed,
            null,
            &data_type,
            @ptrCast(data),
            @ptrCast(&use_max_chars),
        ));
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
