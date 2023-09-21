const std = @import("std");

const math = @import("../../core/math.zig");

const GenericWindow = @import("window.zig").GenericWindow;
const input_device_mapper = @import("input_device_mapper.zig");

pub const MouseButtons = enum {
    left,
    middle,
    right,
    x1,
    x2,
    invalid,
};

pub const GamepadKeys = enum {
    invalid,

    left_analog_x,
    left_analog_y,
    right_analog_x,
    right_analog_y,
    left_trigger,
    right_trigger,

    left_thumb,
    right_thumb,
    special_left,
    special_left_x,
    special_left_y,
    special_right,
    special_right_x,
    special_right_y,
    face_button_bottom,
    face_button_right,
    face_button_left,
    face_button_top,
    left_shoulder,
    right_shoulder,
    left_trigger_threshold,
    right_trigger_threshold,
    dpad_up,
    dpad_down,
    dpad_left,
    dpad_right,

    left_stick_up,
    left_stick_down,
    left_stick_left,
    left_stick_right,

    right_stick_up,
    right_stick_down,
    right_stick_left,
    right_stick_right,

    pub const GamepadKeyNames = struct {
        pub const invalid = "none";

        pub const left_analog_x = "gamepad_left_analog_x";
        pub const left_analog_y = "gamepad_left_analog_y";
        pub const right_analog_x = "gamepad_right_analog_x";
        pub const right_analog_y = "gamepad_right_analog_y";
        pub const left_trigger = "gamepad_left_trigger";
        pub const right_trigger = "gamepad_right_trigger";

        pub const left_thumb = "gamepad_left_thumb";
        pub const right_thumb = "gamepad_right_thumb";
        pub const special_left = "gamepad_special_left";
        pub const special_left_x = "gamepad_special_left_x";
        pub const special_left_y = "gamepad_special_left_y";
        pub const special_right = "gamepad_special_right";
        pub const special_right_x = "gamepad_special_right_x";
        pub const special_right_y = "gamepad_special_right_y";
        pub const face_button_bottom = "gamepad_face_button_bottom";
        pub const face_button_right = "gamepad_face_button_right";
        pub const face_button_left = "gamepad_face_button_left";
        pub const face_button_top = "gamepad_face_button_top";
        pub const left_shoulder = "gamepad_left_shoulder";
        pub const right_shoulder = "gamepad_right_shoulder";
        pub const left_trigger_threshold = "gamepad_left_trigger_threshold";
        pub const right_trigger_threshold = "gamepad_right_trigger_threshold";
        pub const dpad_up = "gamepad_dpad_up";
        pub const dpad_down = "gamepad_dpad_down";
        pub const dpad_left = "gamepad_dpad_left";
        pub const dpad_right = "gamepad_dpad_right";

        pub const left_stick_up = "gamepad_left_stick_up";
        pub const left_stick_down = "gamepad_left_stick_down";
        pub const left_stick_left = "gamepad_left_stick_left";
        pub const left_stick_right = "gamepad_left_stick_right";

        pub const right_stick_up = "gamepad_right_stick_up";
        pub const right_stick_down = "gamepad_right_stick_down";
        pub const right_stick_left = "gamepad_right_stick_left";
        pub const right_stick_right = "gamepad_right_stick_right";
    };

    const Mapping = struct {
        en: GamepadKeys,
        name: []const u8,
    };
    const mappings = [_]Mapping{
        Mapping{ .en = .invalid, .name = GamepadKeyNames.invalid },

        Mapping{ .en = .left_analog_x, .name = GamepadKeyNames.left_analog_x },
        Mapping{ .en = .left_analog_y, .name = GamepadKeyNames.left_analog_y },
        Mapping{ .en = .right_analog_x, .name = GamepadKeyNames.right_analog_x },
        Mapping{ .en = .right_analog_y, .name = GamepadKeyNames.right_analog_y },
        Mapping{ .en = .left_trigger, .name = GamepadKeyNames.left_trigger },
        Mapping{ .en = .right_trigger, .name = GamepadKeyNames.right_trigger },

        Mapping{ .en = .left_thumb, .name = GamepadKeyNames.left_thumb },
        Mapping{ .en = .right_thumb, .name = GamepadKeyNames.right_thumb },
        Mapping{ .en = .special_left, .name = GamepadKeyNames.special_left },
        Mapping{ .en = .special_left_x, .name = GamepadKeyNames.special_left_x },
        Mapping{ .en = .special_left_y, .name = GamepadKeyNames.special_left_y },
        Mapping{ .en = .special_right, .name = GamepadKeyNames.special_right },
        Mapping{ .en = .special_right_x, .name = GamepadKeyNames.special_right_x },
        Mapping{ .en = .special_right_y, .name = GamepadKeyNames.special_right_y },
        Mapping{ .en = .face_button_bottom, .name = GamepadKeyNames.face_button_bottom },
        Mapping{ .en = .face_button_right, .name = GamepadKeyNames.face_button_right },
        Mapping{ .en = .face_button_left, .name = GamepadKeyNames.face_button_left },
        Mapping{ .en = .face_button_top, .name = GamepadKeyNames.face_button_top },
        Mapping{ .en = .left_shoulder, .name = GamepadKeyNames.left_shoulder },
        Mapping{ .en = .right_shoulder, .name = GamepadKeyNames.right_shoulder },
        Mapping{ .en = .left_trigger_threshold, .name = GamepadKeyNames.left_trigger_threshold },
        Mapping{ .en = .right_trigger_threshold, .name = GamepadKeyNames.right_trigger_threshold },
        Mapping{ .en = .dpad_up, .name = GamepadKeyNames.dpad_up },
        Mapping{ .en = .dpad_down, .name = GamepadKeyNames.dpad_down },
        Mapping{ .en = .dpad_left, .name = GamepadKeyNames.dpad_left },
        Mapping{ .en = .dpad_right, .name = GamepadKeyNames.dpad_right },

        Mapping{ .en = .left_stick_up, .name = GamepadKeyNames.left_stick_up },
        Mapping{ .en = .left_stick_down, .name = GamepadKeyNames.left_stick_down },
        Mapping{ .en = .left_stick_left, .name = GamepadKeyNames.left_stick_left },
        Mapping{ .en = .left_stick_right, .name = GamepadKeyNames.left_stick_right },

        Mapping{ .en = .right_stick_up, .name = GamepadKeyNames.right_stick_up },
        Mapping{ .en = .right_stick_down, .name = GamepadKeyNames.right_stick_down },
        Mapping{ .en = .right_stick_left, .name = GamepadKeyNames.right_stick_left },
        Mapping{ .en = .right_stick_right, .name = GamepadKeyNames.right_stick_right },
    };

    pub fn toName(self: GamepadKeys) ?[]const u8 {
        return switch (self) {
            .invalid => GamepadKeyNames.invalid,

            .left_analog_x => GamepadKeyNames.left_analog_x,
            .left_analog_y => GamepadKeyNames.left_analog_y,
            .right_analog_x => GamepadKeyNames.right_analog_x,
            .right_analog_y => GamepadKeyNames.right_analog_y,
            .left_trigger => GamepadKeyNames.left_trigger,
            .right_trigger => GamepadKeyNames.right_trigger,

            .left_thumb => GamepadKeyNames.left_thumb,
            .right_thumb => GamepadKeyNames.right_thumb,
            .special_left => GamepadKeyNames.special_left,
            .special_left_x => GamepadKeyNames.special_left_x,
            .special_left_y => GamepadKeyNames.special_left_y,
            .special_right => GamepadKeyNames.special_right,
            .special_right_x => GamepadKeyNames.special_right_x,
            .special_right_y => GamepadKeyNames.special_right_y,
            .face_button_bottom => GamepadKeyNames.face_button_bottom,
            .face_button_right => GamepadKeyNames.face_button_right,
            .face_button_left => GamepadKeyNames.face_button_left,
            .face_button_top => GamepadKeyNames.face_button_top,
            .left_shoulder => GamepadKeyNames.left_shoulder,
            .right_shoulder => GamepadKeyNames.right_shoulder,
            .left_trigger_threshold => GamepadKeyNames.left_trigger_threshold,
            .right_trigger_threshold => GamepadKeyNames.right_trigger_threshold,
            .dpad_up => GamepadKeyNames.dpad_up,
            .dpad_down => GamepadKeyNames.dpad_down,
            .dpad_left => GamepadKeyNames.dpad_left,
            .dpad_right => GamepadKeyNames.dpad_right,

            .left_stick_up => GamepadKeyNames.left_stick_up,
            .left_stick_down => GamepadKeyNames.left_stick_down,
            .left_stick_left => GamepadKeyNames.left_stick_left,
            .left_stick_right => GamepadKeyNames.left_stick_right,

            .right_stick_up => GamepadKeyNames.right_stick_up,
            .right_stick_down => GamepadKeyNames.right_stick_down,
            .right_stick_left => GamepadKeyNames.right_stick_left,
            .right_stick_right => GamepadKeyNames.right_stick_right,
        };
    }

    pub fn fromName(name: []const u8) ?GamepadKeys {
        inline for (mappings) |x| {
            if (std.mem.eql(u8, name, x.name)) {
                return x.en;
            }
        }
        return null;
    }
};

pub const WindowActivation = enum(u8) {
    activate,
    activate_by_mouse,
    deactivate,
};

pub const WindowZone = enum {
    not_in_window,
    top_left,
    top,
    top_right,
    left,
    client,
    right,
    bottom_left,
    bottom,
    bottom_right,
    title,
    minimise,
    maximise,
    close,
    sysmenu,
};

pub const WindowAction = enum {
    clicked_non_client_area,
    maximise,
    restore,
    window_menu,
};

pub const DropEffect = enum {
    none,
    copy,
    move,
    link,
};

pub const GestureEvent = enum(u8) {
    none,
    scroll,
    magnify,
    swipe,
    rotate,
    long_press,
};

pub const WindowSizeLimits = struct {
    min_width: ?f32,
    min_height: ?f32,
    max_width: ?f32,
    max_height: ?f32,
};

pub const GenericApplicationMessageHandler = struct {
    const Self = @This();
    virtual: struct {
        deinit: ?fn (*Self) void = null,
        shouldProcessUserInputMessages: ?fn (*const Self, wnd: *const GenericWindow) bool = null,
        onKeyChar: ?fn (*Self, codepoint: u32, is_repeat: bool) bool = null,
        onKeyDown: ?fn (*Self, key: i32, char: u32, is_repeat: bool) bool = null,
        onKeyUp: ?fn (*Self, key: i32, char: u32, is_repeat: bool) bool = null,
        onInputLanguageChange: ?fn (*Self, lang: []const u8) void = null,
        onMouseDown: ?fn (*Self, wnd: *const GenericWindow, button: MouseButtons, pos: math.Vector2(f32)) bool = null,
        onMouseUp: ?fn (*Self, wnd: *const GenericWindow, pos: math.Vector2(f32)) bool = null,
        onMouseDoubleClick: ?fn (*Self, wnd: *const GenericWindow, button: MouseButtons, pos: math.Vector2(f32)) bool = null,
        onMouseWheel: ?fn (*Self, delta: f32, pos: math.Vector2(f32)) bool = null,
        onMouseMove: ?fn (*Self) bool = null,
        onRawMouseMove: ?fn (*Self, x: i32, y: i32) bool = null,
        onCursorSet: ?fn (*Self) void = null,
        onControllerAnalog: ?fn (
            *Self,
            key: GamepadKeys,
            platform_user_id: input_device_mapper.PlatformUserId,
            input_device_id: input_device_mapper.InputDeviceId,
            analog_value: f32,
        ) bool = null,
        onControllerButtonPressed: ?fn (
            *Self,
            key: GamepadKeys,
            platform_user_id: input_device_mapper.PlatformUserId,
            input_device_id: input_device_mapper.InputDeviceId,
            is_repeat: bool,
        ) bool = null,
        onControllerButtonReleased: ?fn (
            *Self,
            key: GamepadKeys,
            platform_user_id: input_device_mapper.PlatformUserId,
            input_device_id: input_device_mapper.InputDeviceId,
        ) bool = null,
        onBeginGesture: ?fn (*Self) void = null,
        onTouchGesture: ?fn (
            *Self,
            gesture_type: GestureEvent,
            delta: *const math.Vector2(f32),
            wheel_delta: f32,
            is_inverted: bool,
        ) bool = null,
        onEndGesture: ?fn (*Self) void = null,
    } = undefined,

    pub fn deinit(this: *Self) void {
        if (this.virtual.deinit) |f| {
            f(this);
        }
    }

    pub fn shouldProcessUserInputMessages(this: *const Self, wnd: *const GenericWindow) bool {
        if (this.virtual.shouldProcessUserInputMessages) |f| {
            return f(this, wnd);
        }
        return false;
    }

    pub fn onKeyChar(this: *Self, codepoint: u32, is_repeat: bool) bool {
        if (this.virtual.onKeyChar) |f| {
            return f(this, codepoint, is_repeat);
        }
        return false;
    }

    pub fn onKeyDown(this: *Self, key: i32, char: u32, is_repeat: bool) bool {
        if (this.virtual.onKeyDown) |f| {
            return f(this, key, char, is_repeat);
        }
        return false;
    }

    pub fn onKeyUp(this: *Self, key: i32, char: u32, is_repeat: bool) bool {
        if (this.virtual.onKeyUp) |f| {
            return f(this, key, char, is_repeat);
        }
        return false;
    }

    pub fn onInputLanguageChange(this: *Self, lang: []const u8) void {
        if (this.virtual.onInputLanguageChange) |f| {
            f(this, lang);
        }
    }

    pub fn onMouseDown(this: *Self, wnd: *const GenericWindow, button: MouseButtons, pos: math.Vector2(f32)) bool {
        if (this.virtual.onMouseDown) |f| {
            return f(this, wnd, button, pos);
        }
        return false;
    }

    pub fn onMouseUp(this: *Self, wnd: *const GenericWindow, pos: math.Vector2(f32)) bool {
        if (this.virtual.onMouseUp) |f| {
            return f(this, wnd, pos);
        }
        return false;
    }

    pub fn onMouseDoubleClick(this: *Self, wnd: *const GenericWindow, button: MouseButtons, pos: math.Vector2(f32)) bool {
        if (this.virtual.onMouseDoubleClick) |f| {
            return f(this, wnd, button, pos);
        }
        return false;
    }

    pub fn onMouseWheel(this: *Self, delta: f32, pos: math.Vector2(f32)) bool {
        if (this.virtual.onMouseWheel) |f| {
            return f(this, delta, pos);
        }
        return false;
    }

    pub fn onMouseMove(
        this: *Self,
    ) bool {
        if (this.virtual.onMouseMove) |f| {
            return f(this);
        }
        return false;
    }

    pub fn onRawMouseMove(
        this: *Self,
        x: i32,
        y: i32,
    ) bool {
        if (this.virtual.onRawMouseMove) |f| {
            return f(this, x, y);
        }
        return false;
    }

    pub fn onCursorSet(
        this: *Self,
    ) void {
        if (this.virtual.onCursorSet) |f| {
            f(this);
        }
    }

    pub fn onControllerAnalog(
        this: *Self,
        key: GamepadKeys,
        platform_user_id: input_device_mapper.PlatformUserId,
        input_device_id: input_device_mapper.InputDeviceId,
        analog_value: f32,
    ) bool {
        if (this.virtual.onControllerAnalog) |f| {
            return f(this, key, platform_user_id, input_device_id, analog_value);
        }
        return false;
    }

    pub fn onControllerButtonPressed(
        this: *Self,
        key: GamepadKeys,
        platform_user_id: input_device_mapper.PlatformUserId,
        input_device_id: input_device_mapper.InputDeviceId,
        is_repeat: bool,
    ) bool {
        if (this.virtual.onControllerButtonPressed) |f| {
            return f(this, key, platform_user_id, input_device_id, is_repeat);
        }
        return false;
    }

    pub fn onControllerButtonReleased(
        this: *Self,
        key: GamepadKeys,
        platform_user_id: input_device_mapper.PlatformUserId,
        input_device_id: input_device_mapper.InputDeviceId,
    ) bool {
        if (this.virtual.onControllerButtonReleased) |f| {
            return f(this, key, platform_user_id, input_device_id);
        }
        return false;
    }

    pub fn onBeginGesture(
        this: *Self,
    ) void {
        if (this.virtual.onBeginGesture) |f| {
            f(this);
        }
    }

    pub fn onTouchGesture(
        this: *Self,
        gesture_type: GestureEvent,
        delta: *const math.Vector2(f32),
        wheel_delta: f32,
        is_inverted: bool,
    ) bool {
        if (this.virtual.onTouchGesture) |f| {
            return f(this, gesture_type, delta, wheel_delta, is_inverted);
        }
        return false;
    }

    pub fn onEndGesture(
        this: *Self,
    ) void {
        if (this.virtual.onEndGesture) |f| {
            f(this);
        }
    }
};
