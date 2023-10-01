const std = @import("std");

const interface = @import("../../core/interface.zig");
const math = @import("../../core/math.zig");

const win32 = @import("win32");

const application = @import("../generic/application.zig");
const windows_application = @import("application.zig");
const WindowsApplication = windows_application.WindowsApplication;

const platform_application_misc = @import("../generic/platform_application_misc.zig");
const PlatformApplicationMisc = platform_application_misc.PlatformApplicationMisc;

const window = @import("../generic/window.zig");
const GenericWindow = window.GenericWindow;

pub const WindowsWindow = struct {
    const virtual: *const GenericWindow.Virtual = &interface.populateVirtual(GenericWindow.Virtual, WindowsWindow);
    root: GenericWindow,

    owning_application: *WindowsApplication,
    hwnd: ?win32.foundation.HWND,
    region_width: ?i32 = null,
    region_height: ?i32 = null,
    window_mode: window.WindowMode,
    reference_count: std.atomic.Atomic(i32) = .{ .value = 0 },
    pre_fullscreen_window_placement: win32.ui.windows_and_messaging.WINDOWPLACEMENT = std.mem.zeroes(
        win32.ui.windows_and_messaging.WINDOWPLACEMENT,
    ),
    pre_parent_minimised_window_placement: win32.ui.windows_and_messaging.WINDOWPLACEMENT = std.mem.zeroes(
        win32.ui.windows_and_messaging.WINDOWPLACEMENT,
    ),
    virtual_width: i32,
    virtual_height: i32,
    aspect_ratio: f32,
    is_visible: bool,
    is_first_time_visible: bool,
    initially_minimised: bool,
    initially_maximised: bool,
    dpi_scale_factor: f32,
    handle_manual_dpi_changes: bool,
    com_vtable: *const win32.system.ole.IDropTarget.VTable = &win32.system.ole.IDropTarget.VTable{
        .base = win32.system.com.IUnknown.VTable{
            .QueryInterface = @ptrCast(&WindowsWindow.QueryInterface),
            .AddRef = @ptrCast(&WindowsWindow.AddRef),
            .Release = @ptrCast(&WindowsWindow.Release),
        },
        .DragEnter = @ptrCast(&WindowsWindow.DragEnter),
        .DragOver = @ptrCast(&WindowsWindow.DragOver),
        .DragLeave = @ptrCast(&WindowsWindow.DragLeave),
        .Drop = @ptrCast(&WindowsWindow.Drop),
    },

    pub fn getRoot(self: *WindowsWindow) *GenericWindow {
        return self.root;
    }

    pub fn getIDropTarget(self: *WindowsWindow) *win32.system.ole.IDropTarget {
        return &self.com_vtable;
    }

    pub const app_window_class = win32.zig.L("app-class");

    pub fn init() WindowsWindow {
        return outer: {
            var x = WindowsWindow{
                .root = GenericWindow.init(),
                .hwnd = null,
                .window_mode = .windowed,
                .aspect_ratio = 1.0,
                .is_visible = false,
                .is_first_time_visible = false,
                .initially_minimised = false,
                .initially_maximised = false,
                .dpi_scale_factor = 1.0,
                .pre_fullscreen_window_placement = std.mem.zeroes(
                    win32.ui.windows_and_messaging.WINDOWPLACEMENT,
                ),
                .pre_parent_minimised_window_placement = blk: {
                    var placement = std.mem.zeroes(
                        win32.ui.windows_and_messaging.WINDOWPLACEMENT,
                    );
                    placement.length = @sizeOf(win32.ui.windows_and_messaging.WINDOWPLACEMENT);
                    break :blk placement;
                },
            };
            x.root.virtual = WindowsWindow.virtual;

            break :outer x;
        };
    }

    pub fn build(
        wnd: *WindowsWindow,
        app: *WindowsApplication,
        window_definition: window.GenericWindowDefinition,
        hinstance: win32.foundation.HINSTANCE,
        parent: ?*const WindowsWindow,
        show_immediately: bool,
    ) WindowsWindow {
        _ = show_immediately;
        wnd.root.definition = window_definition;

        wnd.owning_application = app;

        const x_initial_rect = window_definition.x_desired_position orelse 0;
        const y_initial_rect = window_definition.y_desired_position orelse 0;
        const width_initial_rect = window_definition.width_desired_size orelse 0;
        const height_initial_rect = window_definition.height_desired_size orelse 0;

        wnd.dpi_scale_factor = PlatformApplicationMisc.getDpiScaleFactorAtPoint(x_initial_rect, y_initial_rect);

        var client_x: i32 = @intFromFloat(@trunc(x_initial_rect));
        var client_y: i32 = @intFromFloat(@trunc(y_initial_rect));
        var client_width: i32 = @intFromFloat(@trunc(width_initial_rect));
        var client_height: i32 = @intFromFloat(@trunc(height_initial_rect));

        var window_x: i32 = client_x;
        var window_y: i32 = client_y;
        var window_width: i32 = client_width;
        var window_height: i32 = client_height;

        var window_style: u32 = 0;
        var window_ex_style: u32 = 0;

        if (!window_definition.has_os_border) {
            window_ex_style = @intFromEnum(win32.ui.windows_and_messaging.WS_EX_WINDOWEDGE);
            window_ex_style |= switch (window_definition.transparency) {
                .per_window => @intFromEnum(win32.ui.windows_and_messaging.WS_EX_LAYERED),
                .per_pixel => @intFromEnum(win32.ui.windows_and_messaging.WS_EX_COMPOSITED),
                else => 0,
            };

            window_style = @intFromEnum(
                win32.ui.windows_and_messaging.WS_POPUP,
            ) | @intFromEnum(
                win32.ui.windows_and_messaging.WS_CLIPCHILDREN,
            ) | @intFromEnum(
                win32.ui.windows_and_messaging.WS_CLIPSIBLINGS,
            );
            if (window_definition.appears_in_taskbar) {
                window_ex_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_EX_APPWINDOW);
            } else {
                window_ex_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_EX_TOOLWINDOW);
            }

            if (window_definition.is_topmost_window) {
                window_ex_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_EX_TOPMOST);
            }

            if (!window_definition.accepts_input) {
                window_ex_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_EX_TRANSPARENT);
            }
        } else {
            window_ex_style = @intFromEnum(win32.ui.windows_and_messaging.WS_EX_APPWINDOW);
            window_style = @intFromEnum(
                win32.ui.windows_and_messaging.WS_OVERLAPPEDWINDOW,
            ) | @intFromEnum(
                win32.ui.windows_and_messaging.WS_CLIPCHILDREN,
            ) | @intFromEnum(
                win32.ui.windows_and_messaging.WS_CLIPSIBLINGS,
            );

            if (wnd.isRegularWindow()) {
                if (window_definition.has_toolbar_maximise_button) {
                    window_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_MAXIMIZEBOX);
                }
                if (window_definition.has_toolbar_minimise_button) {
                    window_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_MINIMIZEBOX);
                }
                if (window_definition.has_sizing_frame) {
                    window_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_THICKFRAME);
                } else {
                    window_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_BORDER);
                }
            } else {
                window_style |= @intFromEnum(
                    win32.ui.windows_and_messaging.WS_BORDER,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.WS_THICKFRAME,
                );
            }

            var border_rect = win32.foundation.RECT{
                .left = 0,
                .top = 0,
                .right = 0,
                .bottom = 0,
            };
            // HACK FOR THIS
            @setRuntimeSafety(false);
            win32.ui.windows_and_messaging.AdjustWindowRectEx(
                &border_rect,
                @enumFromInt(window_style),
                false,
                @enumFromInt(window_ex_style),
            );

            window_x += border_rect.left;
            window_y += border_rect.top;

            window_width = border_rect.right - border_rect.left;
            window_height = border_rect.bottom - border_rect.top;
        }

        wnd.hwnd = win32.ui.windows_and_messaging.CreateWindowExA(
            window_ex_style,
            app_window_class,
            @ptrCast(&window_definition.title),
            window_style,
            window_x,
            window_y,
            window_width,
            window_height,
            if (parent) |p| p.hwnd else null,
            null,
            hinstance,
            null,
        );

        if (wnd == null) {
            const err = win32.foundation.GetLastError();
            _ = err;
            //TODO(logging): log.warn("Failed to create window: {}", err);
            return;
        }

        if (win32.ui.input.touch.RegisterTouchWindow(wnd.hwnd, 0) == win32.zig.FALSE) {
            const err = win32.foundation.GetLastError();
            _ = err;
            //TODO(logging): log.warn("Failed to register touch window: {}", err);
            return;
        }

        wnd.virtual_width = client_width;
        wnd.virtual_height = client_height;

        wnd.reshapeWindow(client_x, client_y, client_width, client_height);

        if (window_definition.transparency == .per_window) {
            wnd.setOpacity(window_definition.opacity);
        }

        if (!window_definition.has_os_border) {
            const rendering_policy = win32.graphics.dwm.DWMNCRP_DISABLED;
            const enable_nc_client: std.os.windows.BOOL = win32.zig.FALSE;
            _ = win32.graphics.dwm.DwmSetWindowAttribute(
                wnd.hwnd,
                win32.graphics.dwm.DWMWA_NCRENDERING_POLICY,
                &rendering_policy,
                @sizeOf(rendering_policy),
            );
            _ = win32.graphics.dwm.DwmSetWindowAttribute(
                wnd.hwnd,
                win32.graphics.dwm.DWMWA_ALLOW_NCPAINT,
                &enable_nc_client,
                @sizeOf(enable_nc_client),
            );
            if (window_definition.transparency == .per_pixel) {
                var margins = win32.graphics.dwm.MARGINS{
                    .cxLeftWidth = -1,
                    .cxRightWidth = -1,
                    .cyTopHeight = -1,
                    .cyBottomHeight = -1,
                };
                _ = win32.graphics.dwm.DwmExtendFrameIntoClientArea(wnd.hwnd, &margins);
            }
        }

        if (wnd.isRegularWindow() and !window_definition.has_os_border) {
            window_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_CAPTION) |
                @intFromEnum(win32.ui.windows_and_messaging.WS_SYSMENU) |
                @intFromEnum(win32.ui.windows_and_messaging.WS_OVERLAPPED);

            if (window_definition.has_toolbar_maximise_button) {
                window_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_MAXIMIZEBOX);
            }
            if (window_definition.has_toolbar_minimise_button) {
                window_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_MINIMIZEBOX);
            }
            if (window_definition.has_sizing_frame) {
                window_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_THICKFRAME);
            }

            _ = win32.ui.windows_and_messaging.SetWindowLongA(
                wnd.hwnd,
                @enumFromInt(win32.ui.windows_and_messaging.GWL_STYLE),
                window_style,
            );

            var set_window_position_flags: u32 = @intFromEnum(win32.ui.windows_and_messaging.SWP_NOZORDER) |
                @intFromEnum(win32.ui.windows_and_messaging.SWP_NOMOVE) |
                @intFromEnum(win32.ui.windows_and_messaging.SWP_NOSIZE) |
                @intFromEnum(win32.ui.windows_and_messaging.SWP_FRAMECHANGED);

            if (window_definition.activation_policy == .never) {
                set_window_position_flags |= @intFromEnum(win32.ui.windows_and_messaging.SWP_NOACTIVATE);
            }

            _ = win32.ui.windows_and_messaging.SetWindowPos(
                wnd.hwnd,
                null,
                0,
                0,
                0,
                0,
                set_window_position_flags,
            );

            _ = win32.ui.windows_and_messaging.DeleteMenu(
                win32.ui.windows_and_messaging.GetSystemMenu(wnd.hwnd, win32.zig.FALSE),
                win32.ui.windows_and_messaging.SC_CLOSE,
                win32.ui.windows_and_messaging.MF_BYCOMMAND,
            );

            wnd.adjustWindowRegion(client_width, client_height);
        } else if (window_definition.has_os_border) {
            if (!window_definition.has_close_button) {
                win32.ui.windows_and_messaging.EnableMenuItem(
                    win32.ui.windows_and_messaging.GetSystemMenu(wnd.hwnd, win32.zig.FALSE),
                    win32.ui.windows_and_messaging.SC_CLOSE,
                    win32.ui.windows_and_messaging.MF_GRAYED,
                );
            }
        }

        if (wnd.isRegularWindow()) {
            win32.system.ole.RegisterDragDrop(wnd.hwnd, wnd.getIDropTarget());
        }

        return wnd;
    }

    pub fn deinit(self: *WindowsWindow) void {
        if (self.hwnd != null) {
            _ = win32.ui.windows_and_messaging.DestroyWindow(self.hwnd);
            self.hwnd = null;
        }
    }

    pub fn getHwnd(self: *const WindowsWindow) win32.foundation.HWND {
        return self.hwnd.?;
    }

    pub fn onTransparencySupportChanged(self: *WindowsWindow, new: window.WindowTransparency) void {
        if (self.root.definition.transparency == .per_pixel) {
            const style = win32.ui.windows_and_messaging.GetWindowLongA(
                self.hwnd,
                win32.ui.windows_and_messaging.GWL_EXSTYLE,
            );

            if (new == .per_pixel) {
                win32.ui.windows_and_messaging.SetWindowLongA(
                    self.hwnd,
                    win32.ui.windows_and_messaging.GWL_EXSTYLE,
                    style | @intFromEnum(win32.ui.windows_and_messaging.WS_EX_COMPOSITED),
                );

                const margins = win32.graphics.dwm.MARGINS{
                    .cxLeftWidth = -1,
                    .cxRightWidth = -1,
                    .cyTopHeight = -1,
                    .cyBottomHeight = -1,
                };
                win32.graphics.dwm.DwmExtendFrameIntoClientArea(self.hwnd, &margins);
            } else {
                win32.ui.windows_and_messaging.SetWindowLongA(
                    self.hwnd,
                    win32.ui.windows_and_messaging.GWL_EXSTYLE,
                    style & ~@intFromEnum(win32.ui.windows_and_messaging.WS_EX_COMPOSITED),
                );
            }

            win32.ui.windows_and_messaging.SetWindowPos(
                self.hwnd,
                null,
                0,
                0,
                0,
                0,
                @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_FRAMECHANGED,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOACTIVATE,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOMOVE,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOOWNERZORDER,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOREDRAW,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOSIZE,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOSENDCHANGING,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOZORDER,
                ),
            );
        }
    }

    pub fn makeWindowRegionObject(self: *const WindowsWindow, include_border_when_maximised: bool) win32.ui.windows_and_messaging.HRGN {
        var region: ?win32.ui.windows_and_messaging.HRGN = null;
        if (self.region_width != null and self.region_height != null) {
            const region_width = self.region_width.?;
            const region_height = self.region_height.?;

            const is_borderless_window = self.root.definition.type == .game_window and !self.root.definition.has_os_border;
            if (self.isMaximised()) {
                if (is_borderless_window) {
                    var window_info = std.mem.zeroes(win32.ui.windows_and_messaging.WINDOWINFO);
                    window_info.cbSize = @sizeOf(win32.ui.windows_and_messaging.WINDOWINFO);
                    _ = win32.ui.windows_and_messaging.GetWindowInfo(self.hwnd, &window_info);

                    const window_border_size = if (include_border_when_maximised) window_info.cxWindowBorders else 0;
                    region = win32.graphics.gdi.CreateRectRgn(
                        window_border_size,
                        window_border_size,
                        region_width + window_border_size,
                        region_height + window_border_size,
                    );
                } else {
                    const window_border_size = if (include_border_when_maximised) self.getWindowBorderSize() else 0;
                    region = win32.graphics.gdi.CreateRectRgn(
                        window_border_size,
                        window_border_size,
                        region_width - window_border_size,
                        region_height - window_border_size,
                    );
                }
            } else {
                const use_corner_radius = self.window_mode == .windowed and
                    !is_borderless_window and
                    self.root.definition.transparency != .per_pixel and
                    self.root.definition.corner_radius > 0;

                if (use_corner_radius) {
                    region = win32.graphics.gdi.CreateRoundRectRgn(
                        0,
                        0,
                        region_width + 1,
                        region_height + 1,
                        self.root.definition.corner_radius,
                        self.root.definition.corner_radius,
                    );
                } else {
                    region = win32.graphics.gdi.CreateRectRgn(0, 0, region_width, region_height);
                }
            }
        } else {
            var rc_wnd = win32.foundation.RECT{
                .left = 0,
                .top = 0,
                .right = 0,
                .bottom = 0,
            };
            _ = win32.ui.windows_and_messaging.GetWindowRect(self.hwnd, &rc_wnd);
            region = win32.graphics.gdi.CreateRectRgn(
                0,
                0,
                rc_wnd.right - rc_wnd.left,
                rc_wnd.bottom - rc_wnd.top,
            );
        }
        return region.?;
    }

    pub fn disableTouchFeedback(self: *WindowsWindow) void {
        const enabled: std.os.windows.BOOL = win32.zig.FALSE;
        win32.ui.controls.SetWindowFeedbackSetting(
            self.hwnd,
            win32.ui.controls.FEEDBACK_TOUCH_CONTACTVISUALIZATION,
            0,
            @sizeOf(std.os.windows.BOOL),
            @ptrCast(&enabled),
        );
        win32.ui.controls.SetWindowFeedbackSetting(
            self.hwnd,
            win32.ui.controls.FEEDBACK_TOUCH_TAP,
            0,
            @sizeOf(std.os.windows.BOOL),
            @ptrCast(&enabled),
        );
        win32.ui.controls.SetWindowFeedbackSetting(
            self.hwnd,
            win32.ui.controls.FEEDBACK_TOUCH_PRESSANDHOLD,
            0,
            @sizeOf(std.os.windows.BOOL),
            @ptrCast(&enabled),
        );
    }

    pub fn adjustWindowRegion(self: *WindowsWindow, width: i32, height: i32) void {
        self.region_width = width;
        self.region_height = height;

        var region = self.makeWindowRegionObject(true);
        _ = win32.graphics.gdi.SetWindowRgn(self.hwnd, region, win32.zig.TRUE);
    }

    pub fn reshapeWindow(self: *WindowsWindow, new_x: i32, new_y: i32, new_width: i32, new_height: i32) void {
        var window_info = std.mem.zeroes(win32.ui.windows_and_messaging.WINDOWINFO);
        window_info.cbSize = @sizeOf(win32.ui.windows_and_messaging.WINDOWINFO);
        _ = win32.ui.windows_and_messaging.GetWindowInfo(self.hwnd, &window_info);

        self.aspect_ratio = @as(
            f32,
            @floatCast(new_width),
        ) / @as(
            f32,
            @floatCast(new_height),
        );

        if (self.root.definition.has_os_border) {
            var border_rect = win32.foundation.RECT{
                .left = 0,
                .top = 0,
                .right = 0,
                .bottom = 0,
            };
            _ = win32.ui.windows_and_messaging.AdjustWindowRectEx(
                &border_rect,
                @enumFromInt(window_info.dwStyle),
                false,
                @enumFromInt(window_info.dwExStyle),
            );

            new_x += border_rect.left;
            new_y += border_rect.top;

            new_width = border_rect.right - border_rect.left;
            new_height = border_rect.bottom - border_rect.top;
        }

        var window_x: i32 = new_x;
        var window_y: i32 = new_y;

        const virtual_size_changed = (self.virtual_width != new_width) or (self.virtual_height != new_height);
        self.virtual_width = new_width;
        self.virtual_height = new_height;

        if (self.root.definition.changes_often) {
            const old_window_rect = window_info.rcWindow;
            const old_width = old_window_rect.right - old_window_rect.left;
            const old_height = old_window_rect.bottom - old_window_rect.top;

            const min_retained_width = self.root.definition.expected_max_width orelse old_width;
            const min_retained_height = self.root.definition.expected_max_height orelse old_height;
            new_width = @max(new_width, @min(old_width, min_retained_width));
            new_height = @max(new_height, @min(old_height, min_retained_height));
        }

        if (self.isMaximised()) {
            self.restore();
        }

        win32.ui.windows_and_messaging.SetWindowPos(
            self.hwnd,
            null,
            window_x,
            window_y,
            new_width,
            new_height,
            @intFromEnum(win32.ui.windows_and_messaging.SWP_NOZORDER) | @intFromEnum(
                win32.ui.windows_and_messaging.SWP_NOACTIVATE,
            ) | if (self.window_mode == .fullscreen) @intFromEnum(
                win32.ui.windows_and_messaging.SWP_NOSENDCHANGING,
            ) else 0,
        );

        var adjust_size_change = self.root.definition.changes_often or virtual_size_changed;
        var adjust_corners = self.root.definition.type != .menu and self.root.definition.corner_radius > 0;

        if (!self.root.definition.has_os_border and (adjust_size_change or adjust_corners)) {
            self.adjustWindowRegion(self.virtual_width, self.virtual_height);
        }
    }

    pub fn getFullscreenInfo(self: *const WindowsWindow, x: *i32, y: *i32, width: *i32, height: *i32) bool {
        var true_fullscreen = self.window_mode == .fullscreen;

        var monitor = win32.graphics.gdi.MonitorFromWindow(self.hwnd, if (true_fullscreen) win32.graphics.gdi.MONITOR_DEFAULTTOPRIMARY else win32.graphics.gdi.MONITOR_DEFAULTTONEAREST);
        var monitor_info = std.mem.zeroes(win32.graphics.gdi.MONITORINFO);
        monitor_info.cbSize = @sizeOf(win32.graphics.gdi.MONITORINFO);
        _ = win32.graphics.gdi.GetMonitorInfoW(monitor, &monitor_info);

        x.* = monitor_info.rcMonitor.left;
        y.* = monitor_info.rcMonitor.top;
        width.* = monitor_info.rcMonitor.right - monitor_info.rcMonitor.left;
        height.* = monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top;

        return true;
    }

    pub fn moveWindowTo(self: *WindowsWindow, x: i32, y: i32) void {
        var use_x = x;
        var use_y = y;
        if (self.root.definition.has_os_border) {
            const window_style = win32.ui.windows_and_messaging.GetWindowLongA(
                self.hwnd,
                win32.ui.windows_and_messaging.GWL_STYLE,
            );
            const window_ex_style = win32.ui.windows_and_messaging.GetWindowLongA(
                self.hwnd,
                win32.ui.windows_and_messaging.GWL_EXSTYLE,
            );

            var border_rect = win32.foundation.RECT{
                .left = 0,
                .top = 0,
                .right = 0,
                .bottom = 0,
            };
            _ = win32.ui.windows_and_messaging.AdjustWindowRectEx(
                &border_rect,
                @enumFromInt(window_style),
                false,
                @enumFromInt(window_ex_style),
            );

            use_x += border_rect.left;
            use_y += border_rect.top;
        }
        win32.ui.windows_and_messaging.SetWindowPos(
            self.hwnd,
            null,
            use_x,
            use_y,
            0,
            0,
            @intFromEnum(win32.ui.windows_and_messaging.SWP_NOZORDER) | @intFromEnum(
                win32.ui.windows_and_messaging.SWP_NOSIZE,
            ) | @intFromEnum(
                win32.ui.windows_and_messaging.SWP_NOACTIVATE,
            ),
        );
    }

    pub fn bringToFront(self: *WindowsWindow, force: bool) void {
        if (self.isRegularWindow()) {
            if (win32.ui.windows_and_messaging.IsIconic(self.hwnd) == win32.zig.TRUE) {
                win32.ui.windows_and_messaging.ShowWindow(
                    self.hwnd,
                    win32.ui.windows_and_messaging.SW_RESTORE,
                );
            } else {
                win32.ui.input.keyboard_and_mouse.SetActiveWindow(self.hwnd);
            }
        } else {
            const HWND_TOP = win32.zig.typedConst(win32.foundation.HWND, @as(i32, 0));
            var insert_after = HWND_TOP;
            var flags: u32 = @intFromEnum(win32.ui.windows_and_messaging.SWP_NOMOVE) | @intFromEnum(
                win32.ui.windows_and_messaging.SWP_NOSIZE,
            ) | @intFromEnum(
                win32.ui.windows_and_messaging.SWP_NOOWNERZORDER,
            );
            if (!force) {
                flags |= @intFromEnum(win32.ui.windows_and_messaging.SWP_NOACTIVATE);
            }
            if (self.root.definition.is_topmost_window) {
                insert_after = win32.ui.windows_and_messaging.HWND_TOPMOST;
            }

            _ = win32.ui.windows_and_messaging.SetWindowPos(
                self.hwnd,
                insert_after,
                0,
                0,
                0,
                0,
                flags,
            );
        }
    }

    pub fn forceToFront(self: *WindowsWindow) void {
        win32.ui.windows_and_messaging.SetForegroundWindow(self.hwnd);
    }

    pub fn destroy(self: *WindowsWindow) void {
        if (self.reference_count.load(.Monotonic) > 0 and win32.ui.windows_and_messaging.IsWindow(self.hwnd)) {
            const result = win32.system.ole.RevokeDragDrop(self.hwnd);
            if (result == win32.foundation.S_OK) {
                //TODO(logging): log.assert(count == 0, "Not all refs released {}", self.hwnd);
            }
        }

        win32.ui.windows_and_messaging.DestroyWindow(self.hwnd);
    }

    pub fn minimise(self: *WindowsWindow) void {
        if (!self.is_first_time_visible) {
            win32.ui.windows_and_messaging.ShowWindow(
                self.hwnd,
                win32.ui.windows_and_messaging.SW_MINIMIZE,
            );
        } else {
            self.initially_minimised = true;
            self.initially_maximised = false;
        }
    }

    pub fn maximise(self: *WindowsWindow) void {
        if (!self.is_first_time_visible) {
            win32.ui.windows_and_messaging.ShowWindow(
                self.hwnd,
                win32.ui.windows_and_messaging.SW_MAXIMIZE,
            );
        } else {
            self.initially_maximised = true;
            self.initially_minimised = false;
        }
    }

    pub fn restore(self: *const WindowsWindow) void {
        if (!self.is_first_time_visible) {
            win32.ui.windows_and_messaging.ShowWindow(
                self.hwnd,
                @enumFromInt(win32.ui.windows_and_messaging.SW_RESTORE),
            );
        } else {
            self.initially_maximised = false;
            self.initially_minimised = false;
        }
    }

    pub fn show(self: *const WindowsWindow) void {
        if (!self.is_visible) {
            self.is_visible = true;

            var should_activate = false;
            if (self.root.definition.accepts_input) {
                should_activate = self.root.definition.activation_policy == .always;
                if (self.is_first_time_visible and self.root.definition.activation_policy == .first_shown) {
                    should_activate = true;
                }
            }

            var show_window_command = if (should_activate)
                win32.ui.windows_and_messaging.SW_SHOW
            else
                win32.ui.windows_and_messaging.SW_SHOWNOACTIVATE;
            if (self.is_first_time_visible) {
                self.is_first_time_visible = false;
                if (self.initially_minimised) {
                    show_window_command = if (should_activate)
                        win32.ui.windows_and_messaging.SW_MINIMIZE
                    else
                        win32.ui.windows_and_messaging.SW_SHOWMINNOACTIVE;
                } else if (self.initially_maximised) {
                    show_window_command = if (should_activate)
                        win32.ui.windows_and_messaging.SW_SHOWMAXIMIZED
                    else
                        win32.ui.windows_and_messaging.SW_MAXIMIZE;
                }
            }

            win32.ui.windows_and_messaging.ShowWindow(
                self.hwnd,
                show_window_command,
            );
        }
    }

    pub fn hide(self: *WindowsWindow) void {
        if (self.is_visible) {
            self.is_visible = false;
            win32.ui.windows_and_messaging.ShowWindow(
                self.hwnd,
                win32.ui.windows_and_messaging.SW_HIDE,
            );
        }
    }

    pub fn setWindowMode(self: *WindowsWindow, mode: window.WindowMode) void {
        if (self.window_mode == mode)
            return;

        var previous_mode = self.window_mode;
        self.window_mode = mode;

        const true_fullscreen = mode == .fullscreen;

        var window_style = win32.ui.windows_and_messaging.GetWindowLongA(
            self.hwnd,
            win32.ui.windows_and_messaging.GWL_STYLE,
        );
        const fullscreen_mode_style: i32 = @intFromEnum(win32.ui.windows_and_messaging.WS_POPUP);

        var windowed_mode_style = @intFromEnum(
            win32.ui.windows_and_messaging.WS_OVERLAPPED,
        ) | @intFromEnum(
            win32.ui.windows_and_messaging.WS_SYSMENU,
        ) | @intFromEnum(
            win32.ui.windows_and_messaging.WS_CAPTION,
        );
        if (self.isRegularWindow()) {
            if (self.root.definition.has_toolbar_maximise_button) {
                windowed_mode_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_MAXIMIZEBOX);
            }

            if (self.root.definition.has_toolbar_minimise_button) {
                windowed_mode_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_MINIMIZEBOX);
            }

            if (self.root.definition.has_sizing_frame) {
                windowed_mode_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_THICKFRAME);
            } else {
                windowed_mode_style |= @intFromEnum(win32.ui.windows_and_messaging.WS_BORDER);
            }
        } else {
            windowed_mode_style |= @intFromEnum(
                win32.ui.windows_and_messaging.WS_BORDER,
            ) | @intFromEnum(
                win32.ui.windows_and_messaging.WS_POPUP,
            );
        }

        if (mode == .windowed_fullscreen or mode == .fullscreen) {
            if (previous_mode == .windowed) {
                self.pre_fullscreen_window_placement.length = @sizeOf(win32.ui.windows_and_messaging.WINDOWPLACEMENT);
                _ = win32.ui.windows_and_messaging.GetWindowPlacement(
                    self.hwnd,
                    &self.pre_fullscreen_window_placement,
                );
            }

            window_style &= ~windowed_mode_style;
            window_style |= fullscreen_mode_style;

            _ = win32.ui.windows_and_messaging.SetWindowLongA(
                self.hwnd,
                win32.ui.windows_and_messaging.GWL_STYLE,
                window_style,
            );
            _ = win32.ui.windows_and_messaging.SetWindowPos(
                self.hwnd,
                null,
                0,
                0,
                0,
                0,
                @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOMOVE,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOSIZE,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOZORDER,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_FRAMECHANGED,
                ),
            );

            if (true_fullscreen) {
                _ = win32.ui.windows_and_messaging.ShowWindow(self.hwnd, win32.ui.windows_and_messaging.SW_SHOW);
            }

            var client_rect = win32.foundation.RECT{
                .left = 0,
                .top = 0,
                .right = 0,
                .bottom = 0,
            };
            _ = win32.ui.windows_and_messaging.GetClientRect(self.hwnd, &client_rect);

            var monitor = win32.graphics.gdi.MonitorFromWindow(
                self.hwnd,
                if (true_fullscreen) win32.graphics.gdi.MONITOR_DEFAULTTOPRIMARY else win32.graphics.gdi.MONITOR_DEFAULTTONEAREST,
            );
            var monitor_info = std.mem.zeroes(win32.graphics.gdi.MONITORINFO);
            monitor_info.cbSize = @sizeOf(win32.graphics.gdi.MONITORINFO);
            _ = win32.graphics.gdi.GetMonitorInfoW(monitor, &monitor_info);

            var monitor_width = monitor_info.rcMonitor.right - monitor_info.rcMonitor.left;
            var target_client_width = if (true_fullscreen)
                @min(monitor_width, client_rect.right - client_rect.left)
            else
                monitor_width;

            var monitor_height = monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top;
            var target_client_height = if (true_fullscreen)
                @min(monitor_height, client_rect.bottom - client_rect.top)
            else
                monitor_height;

            self.reshapeWindow(
                monitor_info.rcMonitor.left,
                monitor_info.rcMonitor.top,
                target_client_width,
                target_client_height,
            );
        } else {
            window_style &= ~fullscreen_mode_style;
            window_style |= windowed_mode_style;

            _ = win32.ui.windows_and_messaging.SetWindowLongA(
                self.hwnd,
                win32.ui.windows_and_messaging.GWL_STYLE,
                window_style,
            );
            _ = win32.ui.windows_and_messaging.SetWindowPos(
                self.hwnd,
                null,
                0,
                0,
                0,
                0,
                @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOMOVE,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOSIZE,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_NOZORDER,
                ) | @intFromEnum(
                    win32.ui.windows_and_messaging.SWP_FRAMECHANGED,
                ),
            );

            if (self.pre_fullscreen_window_placement.length != 0) {
                _ = win32.ui.windows_and_messaging.SetWindowPlacement(
                    self.hwnd,
                    &self.pre_fullscreen_window_placement,
                );
            }

            var icon: ?win32.ui.windows_and_messaging.HICON = @ptrCast(win32.ui.windows_and_messaging.GetClassLongPtr(
                self.hwnd,
                win32.ui.windows_and_messaging.GCLP_HICON,
            ));
            if (icon) |ic| {
                _ = win32.ui.windows_and_messaging.SendMessageW(
                    self.hwnd,
                    win32.ui.windows_and_messaging.WM_SETICON,
                    win32.ui.windows_and_messaging.ICON_SMALL,
                    @bitCast(@intFromPtr(ic)),
                );
            }
        }
    }

    pub fn isMaximised(self: *const WindowsWindow) bool {
        return win32.ui.windows_and_messaging.IsZoomed(self.hwnd) == win32.zig.TRUE;
    }

    pub fn isMinimised(self: *const WindowsWindow) bool {
        return win32.ui.windows_and_messaging.IsIconic(self.hwnd) == win32.zig.TRUE;
    }

    pub fn isVisible(self: *const WindowsWindow) bool {
        return self.is_visible;
    }

    pub fn getRestoredDimensions(self: *WindowsWindow, x: *i32, y: *i32, width: *i32, height: *i32) bool {
        var window_placement = std.mem.zeroes(win32.ui.windows_and_messaging.WINDOWPLACEMENT);
        window_placement.length = @sizeOf(win32.ui.windows_and_messaging.WINDOWPLACEMENT);

        if (win32.ui.windows_and_messaging.GetWindowPlacement(self.hwnd, &window_placement) != win32.zig.FALSE) {
            const restored = window_placement.rcNormalPosition;
            x.* = restored.left;
            y.* = restored.top;
            width.* = restored.right - restored.left;
            height.* = restored.bottom - restored.top;

            const window_ex_style = win32.ui.windows_and_messaging.GetWindowLongA(
                self.hwnd,
                win32.ui.windows_and_messaging.GWL_EXSTYLE,
            );

            if ((window_ex_style & @intFromEnum(win32.ui.windows_and_messaging.WS_EX_TOOLWINDOW)) == 0) {
                const true_fullscreen = self.window_mode == .fullscreen;
                var monitor = win32.graphics.gdi.MonitorFromWindow(
                    self.hwnd,
                    if (true_fullscreen)
                        win32.graphics.gdi.MONITOR_DEFAULTTOPRIMARY
                    else
                        win32.graphics.gdi.MONITOR_DEFAULTTONEAREST,
                );
                var monitor_info = std.mem.zeroes(win32.graphics.gdi.MONITORINFO);
                monitor_info.cbSize = @sizeOf(win32.graphics.gdi.MONITORINFO);
                _ = win32.graphics.gdi.GetMonitorInfoW(monitor, &monitor_info);

                x.* += monitor_info.rcMonitor.right - monitor_info.rcMonitor.left;
                y.* += monitor_info.rcMonitor.bottom - monitor_info.rcMonitor.top;
            }

            return true;
        } else {
            return false;
        }
    }

    pub fn isManualManageDpiChanges(self: *const WindowsWindow) bool {
        return self.handle_manual_dpi_changes;
    }

    pub fn setManualManageDpiChanges(self: *WindowsWindow, value: bool) void {
        self.handle_manual_dpi_changes = value;
    }

    pub fn adjustCachedSize(self: *const WindowsWindow, size: *math.Vector2(f32)) void {
        if (self.root.definition.changes_often) {
            size.* = math.Vector2(f32).init(self.virtual_width, self.virtual_height);
        } else if (self.hwnd) |hwnd| {
            var client_rect = win32.foundation.RECT{
                .left = 0,
                .top = 0,
                .right = 0,
                .bottom = 0,
            };
            _ = win32.ui.windows_and_messaging.GetClientRect(hwnd, &client_rect);

            size.* = math.Vector2(f32).init(
                client_rect.right - client_rect.left,
                client_rect.bottom - client_rect.top,
            );
        }
    }

    pub fn onParentWindowMinimised(self: *WindowsWindow) void {
        _ = win32.ui.windows_and_messaging.GetWindowPlacement(self.hwnd, &self.pre_minimise_window_placement);
    }

    pub fn onParentWindowRestored(self: *WindowsWindow) void {
        _ = win32.ui.windows_and_messaging.SetWindowPlacement(self.hwnd, &self.pre_minimise_window_placement);
    }

    pub fn setWindowFocus(self: *WindowsWindow) void {
        if (win32.ui.input.keyboard_and_mouse.GetFocus() != self.hwnd) {
            win32.ui.input.keyboard_and_mouse.SetFocus(self.hwnd);
        }
    }

    pub fn setOpacity(self: *WindowsWindow, opacity: f32) void {
        const byte_opacity: std.os.windows.BYTE = @intFromFloat(@trunc(opacity * 255.0));
        _ = win32.ui.windows_and_messaging.SetLayeredWindowAttributes(
            self.hwnd,
            0,
            byte_opacity,
            win32.ui.windows_and_messaging.LWA_ALPHA,
        );
    }

    pub fn enable(self: *WindowsWindow, should_enable: bool) void {
        win32.ui.input.keyboard_and_mouse.EnableWindow(
            self.hwnd,
            if (should_enable) win32.zig.TRUE else win32.zig.FALSE,
        );
    }

    pub fn isEnabled(self: *const WindowsWindow) bool {
        return win32.ui.input.keyboard_and_mouse.IsWindowEnabled(self.hwnd) == win32.zig.TRUE;
    }

    pub fn isPointInWindow(self: *const WindowsWindow, x: i32, y: i32) bool {
        var result = false;

        var region = self.makeWindowRegionObject(false);
        result = win32.graphics.gdi.PtInRegion(region, x, y) == win32.zig.TRUE;
        _ = win32.graphics.gdi.DeleteObject(region);

        return result;
    }

    pub fn getWindowBorderSize(self: *const WindowsWindow) i32 {
        if (self.root.definition.type == .game_window and !self.root.definition.has_os_border) {
            return 0;
        }

        var window_info = std.mem.zeroes(win32.ui.windows_and_messaging.WINDOWINFO);
        window_info.cbSize = @sizeOf(win32.ui.windows_and_messaging.WINDOWINFO);
        _ = win32.ui.windows_and_messaging.GetWindowInfo(self.hwnd, &window_info);

        return window_info.cxWindowBorders;
    }

    pub fn getWindowTitleBarSize(self: *const WindowsWindow) i32 {
        _ = self;
        return win32.ui.windows_and_messaging.GetSystemMetrics(
            win32.ui.windows_and_messaging.SM_CYCAPTION,
        );
    }

    pub fn isForegroundWindow(self: *const WindowsWindow) bool {
        return win32.ui.windows_and_messaging.GetForegroundWindow() == self.hwnd;
    }

    pub fn isFullscreenSupported(self: *const WindowsWindow) bool {
        _ = self;
        return win32.ui.windows_and_messaging.GetSystemMetrics(
            win32.ui.windows_and_messaging.SM_REMOTESESSION,
        ) == win32.zig.FALSE;
    }

    pub fn drawAttention(self: *WindowsWindow, parameters: *const window.WindowDrawAttentionParameters) void {
        var flash_info = std.mem.zeroes(win32.ui.windows_and_messaging.FLASHWINFO);
        flash_info.cbSize = @sizeOf(win32.ui.windows_and_messaging.FLASHWINFO);
        flash_info.hwnd = self.hwnd;

        switch (parameters.type) {
            .until_activated => {
                flash_info.dwFlags = @intFromEnum(win32.ui.windows_and_messaging.FLASHW_TRAY) | @intFromEnum(
                    win32.ui.windows_and_messaging.FLASHW_TIMERNOFG,
                );
            },
            .stop => {
                flash_info.dwFlags = @intFromEnum(win32.ui.windows_and_messaging.FLASHW_STOP);
            },
            else => {
                //TODO(logging): log.assert(false, "Unsupported draw attention type {}", parameters.type);
            },
        }

        _ = win32.ui.windows_and_messaging.FlashWindowEx(&flash_info);
    }

    pub fn isRegularWindow(self: *const WindowsWindow) bool {
        return self.root.definition.is_regular_window;
    }

    // helper for COM
    fn getSelfFromIDropTarget(vt: *win32.system.ole.IDropTarget) *WindowsWindow {
        return @fieldParentPtr(WindowsWindow, "com_vtable", vt);
    }

    // IUnknown
    fn QueryInterface(
        vt: *win32.system.ole.IDropTarget.VTable,
        riid: ?*const win32.zig.Guid,
        ppvObject: ?*?*anyopaque,
    ) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT {
        var self = getSelfFromIDropTarget(vt);
        if (std.mem.eql(u8, &riid.?.Bytes, &win32.system.ole.IID_IDropTarget.Bytes) or
            std.mem.eql(u8, &riid.?.Bytes, &win32.system.com.IID_IUnknown.Bytes))
        {
            self.addRef();
            ppvObject.?.* = @ptrCast(self);
            return win32.foundation.S_OK;
        } else {
            ppvObject.?.* = null;
            return win32.foundation.E_NOINTERFACE;
        }
    }

    fn AddRef(
        vt: *win32.system.ole.IDropTarget.VTable,
    ) callconv(std.os.windows.WINAPI) u32 {
        var self = getSelfFromIDropTarget(vt);
        return self.reference_count.fetchAdd(1, .Monotonic);
    }

    fn Release(
        vt: *win32.system.ole.IDropTarget.VTable,
    ) callconv(std.os.windows.WINAPI) u32 {
        var self = getSelfFromIDropTarget(vt);
        return self.reference_count.fetchSub(1, .Monotonic);
    }

    // IDropTarget
    fn decipherOleData(

    ) windows_application.OLE

    fn DragEnter(
        vt: *win32.system.ole.IDropTarget.VTable,
        pDataObj: ?*win32.system.ole.IDataObject,
        grfKeyState: u32,
        pt: win32.foundation.POINTL,
        pdwEffect: ?*u32,
    ) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT {
        var self = getSelfFromIDropTarget(vt);
        _ = pdwEffect;
        _ = pt;
        _ = grfKeyState;
        _ = pDataObj;
        _ = self;
        return win32.foundation.E_NOTIMPL;
    }

    fn DragOver(
        vt: *win32.system.ole.IDropTarget.VTable,
        grfKeyState: u32,
        pt: win32.foundation.POINTL,
        pdwEffect: ?*u32,
    ) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT {
        var self = getSelfFromIDropTarget(vt);
        _ = pdwEffect;
        _ = pt;
        _ = grfKeyState;
        _ = self;
        return win32.foundation.E_NOTIMPL;
    }

    fn DragLeave(
        vt: *win32.system.ole.IDropTarget.VTable,
    ) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT {
        var self = getSelfFromIDropTarget(vt);
        _ = self;
        return win32.foundation.E_NOTIMPL;
    }

    fn Drop(
        vt: *win32.system.ole.IDropTarget.VTable,
        pDataObj: ?*win32.system.ole.IDataObject,
        grfKeyState: u32,
        pt: win32.foundation.POINTL,
        pdwEffect: ?*u32,
    ) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT {
        var self = getSelfFromIDropTarget(vt);
        _ = pdwEffect;
        _ = pt;
        _ = grfKeyState;
        _ = pDataObj;
        _ = self;
        return win32.foundation.E_NOTIMPL;
    }
};
