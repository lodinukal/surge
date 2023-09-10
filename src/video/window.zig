const std = @import("std");
const definitions = @import("definitions.zig");
const monitor = @import("monitor.zig");
const image = @import("image.zig");

pub const WindowPosCallback = *fn (wnd: *Window, x: i32, y: i32) void;
pub const WindowSizeCallback = *fn (wnd: *Window, width: i32, height: i32) void;
pub const WindowCloseCallback = *fn (wnd: *Window) void;
pub const WindowRefreshCallback = *fn (wnd: *Window) void;
pub const WindowFocusCallback = *fn (wnd: *Window, focused: bool) void;
pub const WindowIconifyCallback = *fn (wnd: *Window, iconified: bool) void;
pub const WindowMaximiseCallback = *fn (wnd: *Window, maximised: bool) void;
pub const WindowFramebufferChangedCallback = *fn (wnd: *Window, width: i32, height: i32) void;
pub const WindowContentScaleCallback = *fn (wnd: *Window, xscale: f32, yscale: f32) void;

pub const Window = struct {
    pub fn init(
        allocator: std.mem.Allocator,
        width: u32,
        height: u32,
        title: []const u8,
        flags: *const definitions.WindowFlags,
        m: ?monitor.Monitor,
        share: *Window,
    ) definitions.Error!*Window {
        _ = flags;
        _ = share;
        _ = m;
        _ = title;
        _ = height;
        _ = width;
        _ = allocator;
    }

    pub fn deinit(wnd: *Window) definitions.Error!void {
        _ = wnd;
    }

    pub fn shouldClose(wnd: *const Window) definitions.Error!bool {
        _ = wnd;
        return false;
    }

    pub fn setShouldClose(wnd: *Window, value: bool) definitions.Error!void {
        _ = wnd;
        _ = value;
    }

    pub fn setTitle(wnd: *Window, title: []const u8) definitions.Error!void {
        _ = wnd;
        _ = title;
    }

    pub fn setIcon(wnd: *Window, images: []const definitions.Image) definitions.Error!void {
        _ = images;
        _ = wnd;
    }

    pub fn getPosition(wnd: *const Window) definitions.Error!definitions.Position {
        _ = wnd;
    }

    pub fn setPosition(wnd: *Window, x: i32, y: i32) definitions.Error!void {
        _ = wnd;
        _ = x;
        _ = y;
    }

    pub fn getSize(wnd: *const Window) definitions.Error!definitions.Size {
        _ = wnd;
    }

    pub fn setSizeLimits(
        wnd: *Window,
        minwidth: i32,
        minheight: i32,
        maxwidth: i32,
        maxheight: i32,
    ) definitions.Error!void {
        _ = wnd;
        _ = minwidth;
        _ = minheight;
        _ = maxwidth;
        _ = maxheight;
    }

    pub fn setAspectRatio(wnd: *Window, numer: i32, denom: i32) definitions.Error!void {
        _ = wnd;
        _ = numer;
        _ = denom;
    }

    pub fn setSize(wnd: *Window, width: i32, height: i32) definitions.Error!void {
        _ = wnd;
        _ = width;
        _ = height;
    }

    pub fn getFramebufferSize(wnd: *const Window) definitions.Error!struct {
        width: i32,
        height: i32,
    } {
        _ = wnd;
    }

    pub fn getFrameSize(wnd: *const Window) definitions.Error!struct {
        left: i32,
        top: i32,
        right: i32,
        bottom: i32,
    } {
        _ = wnd;
    }

    pub fn getContentScale(wnd: *const Window) definitions.Error!struct {
        xscale: f32,
        yscale: f32,
    } {
        _ = wnd;
    }

    pub fn getOpacity(wnd: *const Window) definitions.Error!f32 {
        _ = wnd;
    }

    pub fn setOpacity(wnd: *Window, opacity: f32) definitions.Error!void {
        _ = wnd;
        _ = opacity;
    }

    pub fn iconify(wnd: *Window) definitions.Error!void {
        _ = wnd;
    }

    pub fn restore(wnd: *Window) definitions.Error!void {
        _ = wnd;
    }

    pub fn maximise(wnd: *Window) definitions.Error!void {
        _ = wnd;
    }

    pub fn show(wnd: *Window) definitions.Error!void {
        _ = wnd;
    }

    pub fn hide(wnd: *Window) definitions.Error!void {
        _ = wnd;
    }

    pub fn focus(wnd: *Window) definitions.Error!void {
        _ = wnd;
    }

    pub fn requestAttention(wnd: *Window) definitions.Error!void {
        _ = wnd;
    }

    pub fn getMonitor(wnd: *const Window) definitions.Error!*monitor.Monitor {
        _ = wnd;
    }

    pub fn setMonitor(
        wnd: *Window,
        m: ?monitor.Monitor,
        xpos: i32,
        ypos: i32,
        width: i32,
        height: i32,
        refreshRate: i32,
    ) definitions.Error!void {
        _ = wnd;
        _ = m;
        _ = xpos;
        _ = ypos;
        _ = width;
        _ = height;
        _ = refreshRate;
    }

    pub fn getFlags(wnd: *const Window) definitions.Error!definitions.WindowFlags {
        _ = wnd;
    }

    pub fn setFlags(wnd: *Window, flags: *const definitions.WindowFlags) definitions.Error!void {
        _ = wnd;
        _ = flags;
    }

    pub fn setUserPointer(wnd: *Window, pointer: ?*void) definitions.Error!void {
        _ = wnd;
        _ = pointer;
    }

    pub fn getUserPointer(wnd: *const Window) definitions.Error!?*void {
        _ = wnd;
    }

    pub fn setPosCallback(cb: ?WindowPosCallback) definitions.Error!?WindowPosCallback {
        _ = cb;
    }

    pub fn setSizeCallback(cb: ?WindowSizeCallback) definitions.Error!?WindowSizeCallback {
        _ = cb;
    }

    pub fn setCloseCallback(cb: ?WindowCloseCallback) definitions.Error!?WindowCloseCallback {
        _ = cb;
    }

    pub fn setRefreshCallback(cb: ?WindowRefreshCallback) definitions.Error!?WindowRefreshCallback {
        _ = cb;
    }

    pub fn setFocusCallback(cb: ?WindowFocusCallback) definitions.Error!?WindowFocusCallback {
        _ = cb;
    }

    pub fn setIconifyCallback(cb: ?WindowIconifyCallback) definitions.Error!?WindowIconifyCallback {
        _ = cb;
    }

    pub fn setMaximiseCallback(cb: ?WindowMaximiseCallback) definitions.Error!?WindowMaximiseCallback {
        _ = cb;
    }

    pub fn setFramebufferSizeCallback(
        cb: ?WindowFramebufferChangedCallback,
    ) definitions.Error!?WindowFramebufferChangedCallback {
        _ = cb;
    }

    pub fn setContentScaleCallback(
        cb: ?WindowContentScaleCallback,
    ) definitions.Error!?WindowContentScaleCallback {
        _ = cb;
    }

    pub fn pollEvents() definitions.Error!void {}

    pub fn waitEvents() definitions.Error!void {}

    pub fn waitEventsTimeout(timeout: f64) definitions.Error!void {
        _ = timeout;
    }

    pub fn postEmptyEvent() definitions.Error!void {}
};
