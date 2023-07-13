const std = @import("std");
const pixels = @import("pixels.zig");
const rect = @import("rect.zig");

pub const WindowHandle = struct {
    id: u32,

    pub fn fromId(id: u32) !DisplayHandle {
        return .{ .id = id };
    }

    pub fn init(title: []const u8, width: u32, height: u32, flags: WindowFlags) !WindowHandle {
        _ = title;
        _ = width;
        _ = height;
        _ = flags;
        return WindowHandle.fromId(0);
    }

    pub fn deinit(h: *WindowHandle) void {
        _ = h;
    }

    pub fn initRect(title: []const u8, r: rect.Rect, flags: WindowFlags) !WindowHandle {
        _ = title;
        _ = r;
        _ = flags;
        return WindowHandle.fromId(0);
    }

    pub fn currentGrab() !?WindowHandle {
        return null;
    }

    pub fn getPixelDensity(h: WindowHandle) !f32 {
        _ = h;
        return 1.0;
    }

    pub fn getDisplayScale(h: WindowHandle) !f32 {
        _ = h;
        return 1.0;
    }

    pub fn setFullscreenMode(h: *WindowHandle, mode: *const DisplayMode) !bool {
        _ = h;
        _ = mode;
        return false;
    }

    pub fn getFullscreenMode(h: WindowHandle) !*const DisplayMode {
        _ = h;
        return null;
    }

    pub fn getICCProfile(h: WindowHandle) ![]const u8 {
        _ = h;
        return &[_]u8{};
    }

    pub fn getFormat(h: WindowHandle) !pixels.Format {
        _ = h;
        return pixels.Formats.rgba8888;
    }

    pub fn getWindowFlags(h: WindowHandle) !WindowFlags {
        _ = h;
        return WindowFlags{};
    }

    pub fn setTitle(h: WindowHandle, title: []const u8) !void {
        _ = h;
        _ = title;
    }

    pub fn getTitle(h: WindowHandle) ![]const u8 {
        _ = h;
        return "dummy";
    }

    pub fn setPosition(h: *WindowHandle, p: rect.Point) !void {
        _ = h;
        _ = p;
    }

    pub fn getPosition(h: WindowHandle) !rect.Point {
        _ = h;
        return rect.Point{ .x = 0, .y = 0 };
    }

    pub fn setSize(h: *WindowHandle, size: rect.Point) !void {
        _ = h;
        _ = size;
    }

    pub fn getSize(h: WindowHandle) !rect.Point {
        _ = h;
        return rect.Point{ .x = 0, .y = 0 };
    }

    pub const BordersSize = struct { top: i32, left: i32, bottm: i32, right: i32 };
    pub fn getBordersSize(h: WindowHandle) !BordersSize {
        _ = h;
        return BordersSize{ .top = 0, .left = 0, .bottm = 0, .right = 0 };
    }

    pub fn setClientSize(h: *WindowHandle, size: rect.Point) !void {
        _ = h;
        _ = size;
    }

    pub fn setClientMinimumSize(h: *WindowHandle, size: rect.Point) !void {
        _ = h;
        _ = size;
    }

    pub fn getClientMinimumSize(h: WindowHandle) !rect.Point {
        _ = h;
        return rect.Point{ .x = 0, .y = 0 };
    }

    pub fn setClientMaximumSize(h: *WindowHandle, size: rect.Point) !void {
        _ = h;
        _ = size;
    }

    pub fn getClientMaximumSize(h: WindowHandle) !rect.Point {
        _ = h;
        return rect.Point{ .x = 0, .y = 0 };
    }

    pub fn setBordered(h: *WindowHandle, bordered: bool) !void {
        _ = h;
        _ = bordered;
    }

    pub fn setResizable(h: *WindowHandle, resizable: bool) !void {
        _ = h;
        _ = resizable;
    }

    pub fn setAlwaysOnTop(h: *WindowHandle, always_on_top: bool) !void {
        _ = h;
        _ = always_on_top;
    }

    pub fn show(h: *WindowHandle) !void {
        _ = h;
    }

    pub fn hide(h: *WindowHandle) !void {
        _ = h;
    }

    pub fn raise(h: *WindowHandle) !void {
        _ = h;
    }

    pub fn maximize(h: *WindowHandle) !void {
        _ = h;
    }

    pub fn minimize(h: *WindowHandle) !void {
        _ = h;
    }

    pub fn restore(h: *WindowHandle) !void {
        _ = h;
    }

    pub fn setFullscreen(h: *WindowHandle, fullscreen: bool) !void {
        _ = h;
        _ = fullscreen;
    }

    pub fn setGrab(h: *WindowHandle, grabbed: bool) !void {
        _ = h;
        _ = grabbed;
    }

    pub fn getGrab(h: WindowHandle) !bool {
        _ = h;
        return false;
    }

    pub fn setOpacity(h: *WindowHandle, opacity: f32) !void {
        _ = h;
        _ = opacity;
    }

    pub fn getOpacity(h: WindowHandle) !f32 {
        _ = h;
        return 1.0;
    }

    pub fn flash(h: *WindowHandle, op: FlashOperation) !void {
        _ = h;
        _ = op;
    }
};

pub const DisplayHandle = struct {
    id: u32,

    pub fn fromId(id: u32) !DisplayHandle {
        return .{ .id = id };
    }

    pub fn fromPoint(p: rect.Point) !DisplayHandle {
        _ = p;
        return DisplayHandle.fromId(0);
    }

    pub fn fromRect(r: rect.Rect) !DisplayHandle {
        _ = r;
        return DisplayHandle.fromId(0);
    }

    pub fn fromWindow(h: WindowHandle) !DisplayHandle {
        _ = h;
        return DisplayHandle.fromId(0);
    }

    pub fn getDisplays() ![]DisplayHandle {
        return &[0]DisplayHandle{};
    }

    pub fn getPrimaryDisplay() !DisplayHandle {
        return DisplayHandle.fromId(0);
    }

    pub fn getName(h: DisplayHandle) ![]const u8 {
        _ = h;
        return "dummy";
    }

    pub fn getBounds(h: DisplayHandle) !rect.Rect {
        _ = h;
        return rect.Rect{ .x = 0, .y = 0, .w = 0, .h = 0 };
    }

    pub fn getUsableBounds(h: DisplayHandle) !rect.Rect {
        _ = h;
        return rect.Rect{ .x = 0, .y = 0, .w = 0, .h = 0 };
    }

    pub fn getNaturalOrientation(h: DisplayHandle) !DisplayOrientation {
        _ = h;
        return DisplayOrientation.unknown;
    }

    pub fn getCurrentOrientation(h: DisplayHandle) !DisplayOrientation {
        _ = h;
        return DisplayOrientation.unknown;
    }

    pub fn getContentScale(h: DisplayHandle) !f32 {
        _ = h;
        return 1.0;
    }

    pub fn getFullscreenModes(h: DisplayHandle) ![]const *const DisplayMode {
        _ = h;
        return &[_]*DisplayMode{};
    }

    pub const FullscreenDisplayModeMatch = struct { w: i32, h: i32, refresh_rate: f32, high_dpi: bool };
    pub fn getMatchingFullscreenMode(h: DisplayHandle, props: FullscreenDisplayModeMatch) !?*const DisplayMode {
        _ = h;
        _ = props;
        return null;
    }

    pub fn getDesktopMode(h: DisplayHandle) !*const DisplayMode {
        return &DisplayMode{
            .handle = h,
            .format = 0,
            .width = 0,
            .height = 0,
            .pixel_density = 1.0,
            .refresh_rate = 60.0,
            .driver_data = null,
        };
    }

    pub fn getCurrentMode(h: DisplayHandle) !*const DisplayMode {
        return &DisplayMode{
            .handle = h,
            .format = 0,
            .width = 0,
            .height = 0,
            .pixel_density = 1.0,
            .refresh_rate = 60.0,
            .driver_data = null,
        };
    }
};

pub const SystemTheme = enum(u2) {
    unknown = 0,
    light = 1,
    dark = 2,
};

pub const DisplayMode = struct {
    handle: DisplayHandle,
    format: u32,
    width: u32,
    height: u32,
    pixel_density: f32,
    refresh_rate: f32,
    driver_data: ?*u8 = null,
};

pub const DisplayOrientation = enum(u3) {
    unknown = 0,
    landscape = 1,
    landscape_flipped = 2,
    portrait = 3,
    portrait_flipped = 4,
};

pub const WindowFlags = packed struct(u8) {
    fullscreen: bool = false,
    hidden: bool = false,
    borderless: bool = false,
    resizable: bool = false,
    minimized: bool = false,
    maximized: bool = false,
    mouse_grabbed: bool = false,
    always_on_top: bool = false,
};

pub const FlashOperation = enum(u2) {
    cancel = 0,
    briefly = 1,
    focused = 2,
};

pub fn getDrivers() ![]const []const u8 {
    return &[_][]const u8{"dummy"};
}

pub fn getSystemTheme() !SystemTheme {
    return SystemTheme.unknown;
}

pub fn isScreenSaverEnabled() !bool {
    return false;
}

pub fn enableScreenSaver() !void {}

pub fn disableScreenSaver() !void {}

test "ref" {
    std.testing.refAllDeclsRecursive(@This());
}
