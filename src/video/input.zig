const std = @import("std");
const definitions = @import("definitions.zig");
const monitor = @import("monitor.zig");
const image = @import("image.zig");
const joystick = @import("joystick.zig");
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

pub fn findMapping(guid: []const u8) ?*platform.InternalMapping {
    for (platform.lib.mappings.items) |mapping| {
        const min_length = @min(mapping.guid.len, guid.len);
        if (std.mem.eql(u8, mapping.guid[0..min_length], guid[0..min_length])) {
            return &mapping;
        }
    }
    return null;
}

pub fn isValidElementForJoystick(
    e: *const platform.InternalMapElement,
    joy: *const platform.InternalJoystick,
) bool {
    if (e.typ == .hatbit and (e.index >> 4) >= joy.hats.len) {
        return false;
    } else if (e.typ == .button and e.index >= joy.buttons.len) {
        return false;
    } else if (e.typ == .axis and e.index >= joy.axes.len) {
        return false;
    }
    return true;
}

pub fn findValidMapping(joy: *const platform.InternalJoystick) ?*platform.InternalMapping {
    if (findMapping(joy.guid)) |mapping| {
        inline for (0..std.meta.fields(definitions.GamepadButton)) |i| {
            if (!isValidElementForJoystick(mapping.buttons[i], joy)) {
                return null;
            }
        }
        inline for (0..std.meta.fields(definitions.GamepadAxis)) |i| {
            if (!isValidElementForJoystick(mapping.axes[i], joy)) {
                return null;
            }
        }

        return mapping;
    }
    return null;
}

const Prefix = enum {
    pos,
    neg,
    unsigned,
};

pub fn parseMapping(mapping: *platform.InternalMapping, str: []const u8) bool {
    var fields = [_]struct { name: []const u8, element: ?*platform.InternalMapElement }{
        .{ .name = "platform", .element = null },
        .{ .name = "a", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.a)] },
        .{ .name = "b", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.b)] },
        .{ .name = "x", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.x)] },
        .{ .name = "y", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.y)] },
        .{ .name = "back", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.back)] },
        .{ .name = "start", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.start)] },
        .{ .name = "guide", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.guide)] },
        .{ .name = "leftshoulder", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.left_bumper)] },
        .{ .name = "rightshoulder", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.right_bumper)] },
        .{ .name = "leftstick", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.left_thumb)] },
        .{ .name = "rightstick", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.right_thumb)] },
        .{ .name = "dpup", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.dpad_up)] },
        .{ .name = "dpright", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.dpad_right)] },
        .{ .name = "dpdown", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.dpad_down)] },
        .{ .name = "dpleft", .element = &mapping.buttons[@intFromEnum(definitions.GamepadButton.dpad_left)] },
        .{ .name = "lefttrigger", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.left_trigger)] },
        .{ .name = "righttrigger", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.right_trigger)] },
        .{ .name = "leftx", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.left_x)] },
        .{ .name = "lefty", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.left_y)] },
        .{ .name = "rightx", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.right_x)] },
        .{ .name = "righty", .element = &mapping.axes[@intFromEnum(definitions.GamepadAxis.right_y)] },
    };

    var parser = std.fmt.Parser{ .buf = str };
    var guid = parser.until(',');
    if (guid.len != 32) {
        return false;
    }
    @memcpy(mapping.guid[0..32], guid[0..32]);
    if (!parser.maybe(',')) return false;

    var name = parser.until(',');
    if (name.len > mapping.name.len) {
        return false;
    }
    var m = @min(name.len, mapping.name.len);
    @memcpy(mapping.name[0..m], name[0..m]);
    if (!parser.maybe(',')) return false;

    lp: while (parser.peek(0)) |_| {
        var key_prefix: Prefix = key_prefix: {
            var is_pos = (parser.peek(0) orelse return false) == '+';
            var is_neg = (parser.peek(0) orelse return false) == '-';
            if (is_pos or is_neg) {
                _ = parser.char();
            }
            break :key_prefix if (is_pos) .pos else if (is_neg) .neg else .unsigned;
        };
        _ = key_prefix;
        var key = parser.until(':');
        if (!parser.maybe(':')) return false;

        var val_prefix: Prefix = val_prefix: {
            var is_pos = (parser.peek(0) orelse return false) == '+';
            var is_neg = (parser.peek(0) orelse return false) == '-';
            if (is_pos or is_neg) {
                _ = parser.char();
            }
            break :val_prefix if (is_pos) .pos else if (is_neg) .neg else .unsigned;
        };

        var mapping_source_opt: ?platform.JoystickMappingSource = mapping_source: {
            break :mapping_source switch ((parser.char() orelse return false)) {
                'a' => platform.JoystickMappingSource.axis,
                'b' => platform.JoystickMappingSource.button,
                'h' => platform.JoystickMappingSource.hatbit,
                else => null,
            };
        };

        var value = parser.until(',');
        if (!parser.maybe(',')) return false;
        const mapping_source = mapping_source_opt orelse {
            // std.debug.print("unknown mapping source: {s}\n", .{value});
            continue :lp;
        };

        var min: i8 = -1;
        var max: i8 = 1;
        switch (val_prefix) {
            .pos => min = 0,
            .neg => max = 0,
            else => {},
        }

        var has_axis_invert = has_axis_invert: {
            if (mapping_source != .axis) {
                break :has_axis_invert false;
            }
            if (value[value.len - 1] == '~') {
                value = value[0 .. value.len - 1];
                break :has_axis_invert true;
            }
            break :has_axis_invert false;
        };

        kv: for (fields) |f| {
            if (!std.mem.eql(u8, f.name, key)) {
                continue :kv;
            }

            if (f.element == null) {
                continue :kv;
            }
            var element = f.element.?;

            var index = index: {
                break :index switch (mapping_source) {
                    .hatbit => hatbit: {
                        var inner_parser = std.fmt.Parser{ .buf = value };
                        var hat_contents = inner_parser.until('.');
                        if (hat_contents.len < 1) {
                            continue :kv;
                        }
                        _ = inner_parser.char();
                        var hat = std.fmt.parseInt(u8, hat_contents, 0) catch {
                            continue :kv;
                        };
                        var bit: u8 = @truncate(inner_parser.number() orelse continue :kv);
                        break :hatbit @as(u8, ((hat << 4) | bit));
                    },
                    else => std.fmt.parseInt(u8, value, 0) catch {
                        continue :kv;
                    },
                };
            };

            element.typ = mapping_source;
            element.index = index;

            if (mapping_source == .axis) {
                element.axis_scale = @divTrunc(2, max - min);
                element.axis_offset = -(max + min);

                if (has_axis_invert) {
                    element.axis_scale *= -1;
                    element.axis_offset *= -1;
                }
            }
        }
    }

    for (mapping.guid[0..32]) |*c| {
        c.* = std.ascii.toLower(c.*);
    }

    platform.lib.platform.updateGamepadGuid(mapping.guid);
    return true;
}

pub fn isJoystickPresent(joy: definitions.Joystick) bool {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        return platform.lib.platform.pollJoystick(joy, .presence);
    }
}

pub fn getJoystickAxes(joy: definitions.Joystick) ?[]const f32 {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        if (!platform.lib.platform.pollJoystick(joy, .axes)) return null;
        return internal_joy.axes[0..internal_joy.axes.len];
    }
    return null;
}

pub fn getJoystickButtons(joy: definitions.Joystick) ?[]const definitions.ElementState {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        if (!platform.lib.platform.pollJoystick(joy, .buttons)) return null;
        return internal_joy.buttons[0..internal_joy.buttons.len];
    }
    return null;
}

pub fn getJoystickHats(joy: definitions.Joystick) ?[]const definitions.HatState {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        if (!platform.lib.platform.pollJoystick(joy, .buttons)) return null;
        return internal_joy.hats[0..internal_joy.hats.len];
    }
    return null;
}

pub fn getJoystickName(joy: definitions.Joystick) ?[]const u8 {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        const name_length = std.mem.indexOfScalar(u8, internal_joy.name, 0);
        return internal_joy.name[0..name_length];
    }
    return null;
}

pub fn getJoystickGuid(joy: definitions.Joystick) ?[32]u8 {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        const result: [32]u8 = undefined;
        if (!platform.lib.platform.pollJoystick(internal_joy, .presence)) return null;
        @memcpy(result[0..32], internal_joy.guid[0..32]);
        return result;
    }
    return null;
}

pub fn setJoystickUserPointer(joy: definitions.Joystick, ptr: ?*void) void {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.allocated) return;
        internal_joy.user_pointer = ptr;
    }
}

pub fn getJoystickUserPointer(joy: definitions.Joystick) ?*void {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.allocated) return null;
        return internal_joy.user_pointer;
    }
    return null;
}

pub fn setJoystickConnectionCallback(
    cb: ?platform.JoystickConnectionCallback,
) ?platform.JoystickConnectionCallback {
    if (!initJoysticks()) return null;

    std.mem.swap(?joystick.JoystickConnectionCallback, &platform.lib.callbacks.joystick, &cb);
    return cb;
}

pub fn updateGamepadMappings(str: []const u8) !bool {
    var parser = std.fmt.Parser{ .buf = str };
    while (parser.peek(0)) |c| {
        if (!std.ascii.isHex(c) or c == '#') {
            _ = parser.until('\n');
            _ = parser.char();
            continue;
        }
        var mapping = platform.InternalMapping{};
        if (!parseMapping(&mapping, parser.until('\n'))) {
            return false;
        }
        if (findMapping(mapping.guid)) |previous_mapping| {
            previous_mapping.* = mapping;
        } else try platform.lib.mappings.append(platform.lib.allocator, mapping);
    }

    for (platform.lib.joysticks) |joy| {
        if (!joy.connected) continue;
        joy.mapping = findValidMapping(joy);
    }

    return true;
}

pub fn isJoystickGamepad(joy: definitions.Joystick) bool {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        return internal_joy.mapping != null;
    }
    return null;
}

pub fn getGamepadName(joy: definitions.Joystick) ?[]const u8 {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        if (internal_joy.mapping) |mapping| return std.mem.span(
            @as([*:0]const u8, @ptrCast(mapping.name)),
        ) else return null;
    }
    return null;
}

pub fn getGamepadState(joy: definitions.Joystick) ?definitions.GamepadState {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        if (!platform.lib.platform.pollJoystick(joy, .all)) return null;
        if (internal_joy.mapping == null) return null;
        var mapping = internal_joy.mapping.?;
        var state = definitions.GamepadState{};
        inline for (0..std.meta.fields(definitions.GamepadButton)) |i| {
            const element = mapping.buttons[i];
            switch (element.typ) {
                .button => state.buttons[i] = internal_joy.buttons[@intCast(element.index)],
                .axis => {
                    const value = internal_joy.axes[element.index] * element.axis_scale + element.axis_offset;
                    if (element.axis_offset < 0 or (element.axis_offset == 0 and element.axis_scale > 0)) {
                        if (value >= 0.0) {
                            state.buttons[i] = .press;
                        }
                    } else {
                        if (value <= 0.0) {
                            state.buttons[i] = .press;
                        }
                    }
                },
                .hatbit => {
                    const hat = element.index >> 4;
                    const bit = element.index & 0xF;
                    if ((internal_joy.hats[hat] & bit) != 0) {
                        state.buttons[i] = .press;
                    }
                },
            }
        }
        inline for (0..std.meta.fields(definitions.GamepadAxis)) |i| {
            const element = mapping.axes[i];
            switch (element.typ) {
                .axis => {
                    const value = internal_joy.axes[element.index] * element.axis_scale + element.axis_offset;
                    state.axes[i] = @min(@max(value, -1.0), 1.0);
                },
                .hatbit => {
                    const hat = element.index >> 4;
                    const bit = element.index & 0xF;
                    if ((internal_joy.hats[hat] & bit) != 0) {
                        state.axes[i] = 1.0;
                    } else {
                        state.axes[i] = -1.0;
                    }
                },
                .button => {
                    state.axes[i] = internal_joy.buttons[
                        @intCast(
                            element.index,
                        )
                    ].toFloat() * 1.0 - 1.0;
                },
            }
        }
        return state;
    }
    return null;
}

fn joystickFromDefinition(joy: definitions.Joystick) ?*platform.InternalJoystick {
    if (!initJoysticks()) return null;

    var internal_joy = &platform.lib.joysticks[@intFromEnum(joy)];
    if (!internal_joy.connected) return null;

    return internal_joy;
}
