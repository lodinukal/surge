const std = @import("std");
const definitions = @import("definitions.zig");
const monitor = @import("monitor.zig");
const image = @import("image.zig");
const platform = @import("./platforms/platform.zig");
const main = @import("main.zig");

const Window = @import("window.zig").Window;

const Cursor = @import("cursor.zig").Cursor;

pub const WindowMouseButtonCallback = *fn (
    wnd: *Window,
    button: definitions.MouseButton,
    action: definitions.ElementState,
    mods: definitions.Modifier,
) void;
pub const WindowCursorPosCallback = *fn (wnd: *Window, x: f64, y: f64) void;
pub const WindowCursorEnterCallback = *fn (wnd: *Window, entered: bool) void;
pub const WindowScrollCallback = *fn (wnd: *Window, x: f64, y: f64) void;
pub const WindowKeyCallback = *fn (
    wnd: *Window,
    key: definitions.Key,
    scancode: i32,
    action: definitions.ElementState,
    mods: definitions.Modifiers,
) void;
pub const WindowCharCallback = *fn (wnd: *Window, ch: u21) void;
pub const WindowCharModsCallback = *fn (wnd: *Window, ch: u21, mods: definitions.Modifier) void;
pub const WindowDropCallback = *fn (wnd: *Window, paths: []const []const u8) void;

pub fn getInputMode(
    wnd: *const Window,
    mode: definitions.InputMode,
) definitions.InputModePayload {
    const internal_window: *platform.InternalWindow = @ptrCast(wnd);

    return switch (mode) {
        .cursor => .{ .cursor = internal_window.cursor_mode },
        .sticky_keys => .{ .sticky_keys = internal_window.sticky_keys },
        .sticky_mouse_buttons => .{ .sticky_mouse_buttons = internal_window.sticky_mouse_buttons },
        .lock_key_mods => .{ .lock_key_mods = internal_window.lock_key_mods },
        .raw_mouse_motion => .{ .raw_mouse_motion = internal_window.raw_mouse_motion },
    };
}

pub fn setInputMode(
    wnd: *Window,
    value: definitions.InputModePayload,
) definitions.Error!void {
    const internal_window: *platform.InternalWindow = @ptrCast(wnd);

    switch (value) {
        .cursor => |mode| {
            if (internal_window.cursor_mode == mode)
                return;

            internal_window.cursor_mode = mode;

            const result = platform.lib.platform.getCursorPos(internal_window);
            internal_window.virtual_cursor_pos_x = result.x;
            internal_window.virtual_cursor_pos_y = result.y;

            platform.lib.platform.setCursorMode(internal_window, mode);
        },
        .sticky_keys => |new| {
            if (internal_window.sticky_keys == new)
                return;

            if (!new) {
                inline for (std.meta.fields(definitions.Key)) |k| {
                    if (internal_window.keys[@intCast(k.value)] == .stick) {
                        internal_window.keys[@intCast(k.value)] = .release;
                    }
                }
            }

            internal_window.sticky_keys = new;
        },
        .sticky_mouse_buttons => |new| {
            if (internal_window.sticky_mouse_buttons == new)
                return;

            if (!new) {
                inline for (std.meta.fields(definitions.MouseButton)) |b| {
                    if (internal_window.mouse_buttons[@intCast(b.value)] == .stick) {
                        internal_window.mouse_buttons[@intCast(b.value)] = .release;
                    }
                }
            }

            internal_window.sticky_mouse_buttons = new;
        },
        .lock_key_mods => |new| {
            internal_window.lock_key_mods = new;
        },
        .raw_mouse_motion => |new| {
            if (!isRawMouseMotionSupported()) {
                main.setErrorString("Raw mouse motion is not supported on this platform.");
                return definitions.Error.PlatformError;
            }

            if (internal_window.raw_mouse_motion == new)
                return;

            internal_window.raw_mouse_motion = new;

            platform.lib.platform.setRawMouseMotion(internal_window, new);
        },
    }
}

pub fn isRawMouseMotionSupported() bool {
    return platform.lib.platform.isRawMouseMotionSupported();
}

pub fn getKeyName(key: definitions.Key, scancode: i32) definitions.Error!?[]const u8 {
    if (key != .unknown) {
        const ikey: i32 = @intFromEnum(key);
        if (key != .kp_equal and
            (ikey < @intFromEnum(.kp_0) or
            ikey > @intFromEnum(.kp_add)) and
            (ikey < @intFromEnum(.apostrophe) or
            ikey > @intFromEnum(.world_2)))
        {
            return null;
        }

        scancode = platform.lib.platform.getKeyScancode(key);
    }

    return platform.lib.platform.getScancodeName(scancode);
}

pub fn getKeyScancode(key: definitions.Key) ?i32 {
    if (key == .unknown) {
        return null;
    }
    return platform.lib.platform.getKeyScancode(key);
}

pub fn getKey(
    wnd: *const Window,
    key: definitions.Key,
) definitions.ElementState {
    const internal_window: *platform.InternalWindow = @ptrCast(wnd);
    if (key == .unknown) {
        return definitions.ElementState.release;
    }

    if (internal_window.keys[@intFromEnum(key)] == .stick) {
        internal_window.keys[@intFromEnum(key)] = .release;
        return .press;
    }

    return internal_window.keys[@intFromEnum(key)];
}

pub fn getMouseButton(
    wnd: *const Window,
    button: definitions.MouseButton,
) definitions.ElementState {
    const internal_window: *platform.InternalWindow = @ptrCast(wnd);

    if (internal_window.mouse_buttons[@intFromEnum(button)] == .stick) {
        internal_window.mouse_buttons[@intFromEnum(button)] = .release;
        return .press;
    }

    return internal_window.mouse_buttons[@intFromEnum(button)];
}

pub fn getCursorPos(wnd: *const Window) struct { x: f64, y: f64 } {
    const internal_window: *platform.InternalWindow = @ptrCast(wnd);

    if (internal_window.cursor_mode == .disabled) {
        return .{ .x = internal_window.virtual_cursor_pos_x, .y = internal_window.virtual_cursor_pos_y };
    }

    return platform.lib.platform.getCursorPos(internal_window);
}

pub fn setCursorPos(wnd: *Window, x: f64, y: f64) void {
    const internal_window: *platform.InternalWindow = @ptrCast(wnd);

    if (!platform.lib.platform.isWindowFocused(wnd)) {
        return;
    }

    if (internal_window.cursor_mode == .disabled) {
        internal_window.virtual_cursor_pos_x = x;
        internal_window.virtual_cursor_pos_y = y;
        return;
    }

    platform.lib.platform.setCursorPos(internal_window, x, y);
}

pub fn setCursor(wnd: *Window, cursor: *Cursor) void {
    const internal_window: *platform.InternalWindow = @ptrCast(wnd);
    const internal_cursor: *platform.InternalCursor = @ptrCast(cursor);

    internal_window.cursor = internal_cursor;
    platform.lib.platform.setCursor(internal_window, internal_cursor);
}

pub fn setKeyCallback(handle: *Window, cb: ?WindowKeyCallback) ?WindowKeyCallback {
    const internal_window: *platform.InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowKeyCallback, &internal_window.callbacks.key, &cb);
    return cb;
}

pub fn setCharCallback(handle: *Window, cb: ?WindowCharCallback) ?WindowCharCallback {
    const internal_window: *platform.InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowCharCallback, &internal_window.callbacks.char, &cb);
    return cb;
}

pub fn setCharModsCallback(handle: *Window, cb: ?WindowCharModsCallback) definitions.Error!?WindowCharModsCallback {
    const internal_window: *platform.InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowCharModsCallback, &internal_window.callbacks.char_mods, &cb);
    return cb;
}

pub fn setMouseButtonCallback(
    handle: *Window,
    cb: ?WindowMouseButtonCallback,
) ?WindowMouseButtonCallback {
    const internal_window: *platform.InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowMouseButtonCallback, &internal_window.callbacks.mouse_button, &cb);
    return cb;
}

pub fn setCursorPosCallback(
    handle: *Window,
    cb: ?WindowCursorPosCallback,
) ?WindowCursorPosCallback {
    const internal_window: *platform.InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowCursorPosCallback, &internal_window.callbacks.cursor_pos, &cb);
    return cb;
}

pub fn setCursorEnterCallback(
    handle: *Window,
    cb: ?WindowCursorEnterCallback,
) definitions.Error!?WindowCursorEnterCallback {
    const internal_window: *platform.InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowCursorEnterCallback, &internal_window.callbacks.cursor_enter, &cb);
    return cb;
}

pub fn setScrollCallback(
    handle: *Window,
    cb: ?WindowScrollCallback,
) definitions.Error!?WindowScrollCallback {
    const internal_window: *platform.InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowScrollCallback, &internal_window.callbacks.scroll, &cb);
    return cb;
}

pub fn setDropCallback(
    handle: *Window,
    cb: ?WindowDropCallback,
) definitions.Error!?WindowDropCallback {
    const internal_window: *platform.InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowDropCallback, &internal_window.callbacks.drop, &cb);
    return cb;
}

pub fn setClipboardString(wnd: *Window, s: []const u8) void {
    _ = wnd;
    platform.lib.platform.setClipboardString(s);
}

pub fn getClipboardString(
    wnd: *const Window,
) ?[]const u8 {
    _ = wnd;
    return platform.lib.platform.getClipboardString();
}

pub fn getTime() f64 {
    const numer: f64 = @floatFromInt((platform.getTimerValue() - platform.lib.timer.offset));
    const denom: f64 = @floatFromInt(platform.getTimerFrequency());
    return numer / denom;
}

pub fn setTime(time: f64) void {
    const ffreq: f64 = @floatFromInt(platform.getTimerFrequency());
    const other: u64 = @intCast(time * ffreq);
    platform.lib.timer.offset = platform.getTimerValue() - other;
}

pub fn getTimerValue() u64 {
    return platform.getTimerValue();
}

pub fn getTimerFrequency() u64 {
    return platform.getTimerFrequency();
}

pub fn initJoysticks() bool {
    if (!platform.lib.joysticks_initialised) {
        if (!platform.lib.platform.initJoysticks()) {
            platform.lib.platform.deinitJoysticks();
            return false;
        }
    }
    platform.lib.joysticks_initialised = true;
    return true;
}

pub fn isJoystickPresent(joy: definitions.Joystick) bool {
    if (!initJoysticks()) return false;
    return platform.lib.platform.isJoystickPresent(joy);
}
