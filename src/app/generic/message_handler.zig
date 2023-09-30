const std = @import("std");

const interface = @import("../../core/interface.zig");
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
    pub const Virtual = interface.VirtualTable(struct {
        deinit: fn (*Self) void,
        shouldProcessUserInputMessages: fn (
            *const Self,
            wnd: *const GenericWindow,
        ) bool,
        onKeyChar: fn (
            *Self,
            codepoint: u32,
            is_repeat: bool,
        ) bool,
        onKeyDown: fn (
            *Self,
            key: i32,
            char: u32,
            is_repeat: bool,
        ) bool,
        onKeyUp: fn (
            *Self,
            key: i32,
            char: u32,
            is_repeat: bool,
        ) bool,
        onInputLanguageChange: fn (
            *Self,
            lang: []const u8,
        ) void,
        onMouseDown: fn (
            *Self,
            wnd: *const GenericWindow,
            button: MouseButtons,
            pos: math.Vector2(f32),
        ) bool,
        onMouseUp: fn (
            *Self,
            wnd: *const GenericWindow,
            pos: math.Vector2(f32),
        ) bool,
        onMouseDoubleClick: fn (
            *Self,
            wnd: *const GenericWindow,
            button: MouseButtons,
            pos: math.Vector2(f32),
        ) bool,
        onMouseWheel: fn (
            *Self,
            delta: f32,
            pos: math.Vector2(f32),
        ) bool,
        onMouseMove: fn (*Self) bool,
        onRawMouseMove: fn (*Self, x: i32, y: i32) bool,
        onCursorSet: fn (*Self) void,
        onControllerAnalog: fn (
            *Self,
            key: GamepadKeys,
            platform_user_id: input_device_mapper.PlatformUserId,
            input_device_id: input_device_mapper.InputDeviceId,
            analog_value: f32,
        ) bool,
        onControllerButtonPressed: fn (
            *Self,
            key: GamepadKeys,
            platform_user_id: input_device_mapper.PlatformUserId,
            input_device_id: input_device_mapper.InputDeviceId,
            is_repeat: bool,
        ) bool,
        onControllerButtonReleased: fn (
            *Self,
            key: GamepadKeys,
            platform_user_id: input_device_mapper.PlatformUserId,
            input_device_id: input_device_mapper.InputDeviceId,
        ) bool,
        onBeginGesture: fn (*Self) void,
        onTouchGesture: fn (
            *Self,
            gesture_type: GestureEvent,
            delta: math.Vector2(f32),
            wheel_delta: f32,
            is_inverted: bool,
        ) bool,
        onEndGesture: fn (*Self) void,
        onTouchStarted: fn (
            *Self,
            wnd: *GenericWindow,
            location: math.Vector2(f32),
            force: f32,
            platform_user_id: input_device_mapper.PlatformUserId,
            device_id: input_device_mapper.InputDeviceId,
        ) bool,
        onTouchMoved: fn (
            *Self,
            location: math.Vector2(f32),
            force: f32,
            index: i32,
            platform_user_id: input_device_mapper.PlatformUserId,
            device_id: input_device_mapper.InputDeviceId,
        ) bool,
        onTouchEnded: fn (
            *Self,
            location: math.Vector2(f32),
            index: i32,
            platform_user_id: input_device_mapper.PlatformUserId,
            device_id: input_device_mapper.InputDeviceId,
        ) bool,
        onTouchForceChanged: fn (
            *Self,
            location: math.Vector2(f32),
            force: f32,
            index: i32,
            platform_user_id: input_device_mapper.PlatformUserId,
            device_id: input_device_mapper.InputDeviceId,
        ) bool,
        onTouchFirstMove: fn (
            *Self,
            location: math.Vector2(f32),
            force: f32,
            index: i32,
            platform_user_id: input_device_mapper.PlatformUserId,
            device_id: input_device_mapper.InputDeviceId,
        ) bool,
        shouldSimulateGesture: fn (
            *Self,
            gesture: GestureEvent,
            enable: bool,
        ) void,
        onMotionDetected: fn (
            *Self,
            tilt: math.Vector3(f32),
            rotation_rate: math.Vector3(f32),
            gravity: math.Vector3(f32),
            acceleration: math.Vector3(f32),
            platform_user_id: input_device_mapper.PlatformUserId,
            device_id: input_device_mapper.InputDeviceId,
        ) bool,
        onSizeChanged: fn (
            *Self,
            wnd: *GenericWindow,
            width: i32,
            height: i32,
            minimised: bool,
        ) bool,
        onOsPaint: fn (
            *Self,
            wnd: *GenericWindow,
        ) void,
        getSizeLimitsForWindow: fn (
            *const Self,
            wnd: *GenericWindow,
        ) ?WindowSizeLimits,
        onResizingWindow: fn (
            *Self,
            wnd: *GenericWindow,
        ) void,
        beginReshapingWindow: fn (
            *Self,
            wnd: *GenericWindow,
        ) bool,
        finishedReshapingWindow: fn (
            *Self,
            wnd: *GenericWindow,
        ) void,
        handleDpiScaleChanged: fn (
            *Self,
            wnd: *GenericWindow,
        ) void,
        signalSystemDpiChanged: fn (
            *Self,
            wnd: *GenericWindow,
        ) void,
        onMovedWindow: fn (
            *Self,
            wnd: *GenericWindow,
            x: i32,
            y: i32,
        ) void,
        onWindowActivationChanged: fn (
            *Self,
            wnd: *GenericWindow,
            activation_type: WindowActivation,
        ) bool,
        onApplicationActivationChanged: fn (
            *Self,
            is_active: bool,
        ) bool,
        onConvertibleLaptopModeChanged: fn (
            *Self,
        ) bool,
        getWindowZoneForPaint: fn (
            *Self,
            wnd: *GenericWindow,
            x: i32,
            y: i32,
        ) WindowZone,
        onWindowClose: fn (
            *Self,
            wnd: *GenericWindow,
        ) void,
        onDragEnterText: fn (
            *Self,
            wnd: *GenericWindow,
            text: []const u8,
        ) DropEffect,
        onDragEnterFiles: fn (
            *Self,
            wnd: *GenericWindow,
            files: []const []const u8,
        ) DropEffect,
        onDragEnterExternal: fn (
            *Self,
            wnd: *GenericWindow,
            text: []const u8,
            files: []const []const u8,
        ) DropEffect,
        onDragOver: fn (
            *Self,
            wnd: *GenericWindow,
        ) DropEffect,
        onDragLeave: fn (
            *Self,
            wnd: *GenericWindow,
        ) void,
        onDragDrop: fn (
            *Self,
            wnd: *GenericWindow,
        ) DropEffect,
        onWindowAction: fn (
            *Self,
            wnd: *GenericWindow,
            action: WindowAction,
        ) bool,
        setCursorPos: fn (
            *Self,
            pos: math.Vector2(f32),
        ) void,
    });
    virtual: ?*const Virtual = null,

    pub fn deinit(this: *Self) void {
        if (this.virtual) |v| if (v.deinit) |f| {
            f(this);
        };
    }

    pub fn shouldProcessUserInputMessages(this: *const Self, wnd: *const GenericWindow) bool {
        if (this.virtual) |v| if (v.shouldProcessUserInputMessages) |f| {
            return f(this, wnd);
        };
        return false;
    }

    pub fn onKeyChar(this: *Self, codepoint: u32, is_repeat: bool) bool {
        if (this.virtual) |v| if (v.onKeyChar) |f| {
            return f(this, codepoint, is_repeat);
        };
        return false;
    }

    pub fn onKeyDown(this: *Self, key: i32, char: u32, is_repeat: bool) bool {
        if (this.virtual) |v| if (v.onKeyDown) |f| {
            return f(this, key, char, is_repeat);
        };
        return false;
    }

    pub fn onKeyUp(this: *Self, key: i32, char: u32, is_repeat: bool) bool {
        if (this.virtual) |v| if (v.onKeyUp) |f| {
            return f(this, key, char, is_repeat);
        };
        return false;
    }

    pub fn onInputLanguageChange(this: *Self, lang: []const u8) void {
        if (this.virtual) |v| if (v.onInputLanguageChange) |f| {
            f(this, lang);
        };
    }

    pub fn onMouseDown(this: *Self, wnd: *const GenericWindow, button: MouseButtons, pos: math.Vector2(f32)) bool {
        if (this.virtual) |v| if (v.onMouseDown) |f| {
            return f(this, wnd, button, pos);
        };
        return false;
    }

    pub fn onMouseUp(this: *Self, wnd: *const GenericWindow, pos: math.Vector2(f32)) bool {
        if (this.virtual) |v| if (v.onMouseUp) |f| {
            return f(this, wnd, pos);
        };
        return false;
    }

    pub fn onMouseDoubleClick(this: *Self, wnd: *const GenericWindow, button: MouseButtons, pos: math.Vector2(f32)) bool {
        if (this.virtual) |v| if (v.onMouseDoubleClick) |f| {
            return f(this, wnd, button, pos);
        };
        return false;
    }

    pub fn onMouseWheel(this: *Self, delta: f32, pos: math.Vector2(f32)) bool {
        if (this.virtual) |v| if (v.onMouseWheel) |f| {
            return f(this, delta, pos);
        };
        return false;
    }

    pub fn onMouseMove(
        this: *Self,
    ) bool {
        if (this.virtual) |v| if (v.onMouseMove) |f| {
            return f(this);
        };
        return false;
    }

    pub fn onRawMouseMove(
        this: *Self,
        x: i32,
        y: i32,
    ) bool {
        if (this.virtual) |v| if (v.onRawMouseMove) |f| {
            return f(this, x, y);
        };
        return false;
    }

    pub fn onCursorSet(
        this: *Self,
    ) void {
        if (this.virtual) |v| if (v.onCursorSet) |f| {
            f(this);
        };
    }

    pub fn onControllerAnalog(
        this: *Self,
        key: GamepadKeys,
        platform_user_id: input_device_mapper.PlatformUserId,
        input_device_id: input_device_mapper.InputDeviceId,
        analog_value: f32,
    ) bool {
        if (this.virtual) |v| if (v.onControllerAnalog) |f| {
            return f(this, key, platform_user_id, input_device_id, analog_value);
        };
        return false;
    }

    pub fn onControllerButtonPressed(
        this: *Self,
        key: GamepadKeys,
        platform_user_id: input_device_mapper.PlatformUserId,
        input_device_id: input_device_mapper.InputDeviceId,
        is_repeat: bool,
    ) bool {
        if (this.virtual) |v| if (v.onControllerButtonPressed) |f| {
            return f(this, key, platform_user_id, input_device_id, is_repeat);
        };
        return false;
    }

    pub fn onControllerButtonReleased(
        this: *Self,
        key: GamepadKeys,
        platform_user_id: input_device_mapper.PlatformUserId,
        input_device_id: input_device_mapper.InputDeviceId,
    ) bool {
        if (this.virtual) |v| if (v.onControllerButtonReleased) |f| {
            return f(this, key, platform_user_id, input_device_id);
        };
        return false;
    }

    pub fn onBeginGesture(
        this: *Self,
    ) void {
        if (this.virtual) |v| if (v.onBeginGesture) |f| {
            f(this);
        };
    }

    pub fn onTouchGesture(
        this: *Self,
        gesture_type: GestureEvent,
        delta: math.Vector2(f32),
        wheel_delta: f32,
        is_inverted: bool,
    ) bool {
        if (this.virtual) |v| if (v.onTouchGesture) |f| {
            return f(this, gesture_type, delta, wheel_delta, is_inverted);
        };
        return false;
    }

    pub fn onEndGesture(
        this: *Self,
    ) void {
        if (this.virtual) |v| if (v.onEndGesture) |f| {
            f(this);
        };
    }

    pub fn onTouchStarted(
        this: *Self,
        wnd: *GenericWindow,
        location: math.Vector2(f32),
        force: f32,
        platform_user_id: input_device_mapper.PlatformUserId,
        device_id: input_device_mapper.InputDeviceId,
    ) bool {
        if (this.virtual) |v| if (v.onTouchStarted) |f| {
            return f(
                this,
                wnd,
                location,
                force,
                platform_user_id,
                device_id,
            );
        };
        return false;
    }

    pub fn onTouchMoved(
        this: *Self,
        location: math.Vector2(f32),
        force: f32,
        index: i32,
        platform_user_id: input_device_mapper.PlatformUserId,
        device_id: input_device_mapper.InputDeviceId,
    ) bool {
        if (this.virtual) |v| if (v.onTouchMoved) |f| {
            return f(
                this,
                location,
                force,
                index,
                platform_user_id,
                device_id,
            );
        };
        return false;
    }

    pub fn onTouchEnded(
        this: *Self,
        location: math.Vector2(f32),
        index: i32,
        platform_user_id: input_device_mapper.PlatformUserId,
        device_id: input_device_mapper.InputDeviceId,
    ) bool {
        if (this.virtual) |v| if (v.onTouchEnded) |f| {
            return f(
                this,
                location,
                index,
                platform_user_id,
                device_id,
            );
        };
        return false;
    }

    pub fn onTouchForceChanged(
        this: *Self,
        location: math.Vector2(f32),
        force: f32,
        index: i32,
        platform_user_id: input_device_mapper.PlatformUserId,
        device_id: input_device_mapper.InputDeviceId,
    ) bool {
        if (this.virtual) |v| if (v.onTouchForceChanged) |f| {
            return f(
                this,
                location,
                force,
                index,
                platform_user_id,
                device_id,
            );
        };
        return false;
    }

    pub fn onTouchFirstMove(
        this: *Self,
        location: math.Vector2(f32),
        force: f32,
        index: i32,
        platform_user_id: input_device_mapper.PlatformUserId,
        device_id: input_device_mapper.InputDeviceId,
    ) bool {
        if (this.virtual) |v| if (v.onTouchFirstMove) |f| {
            return f(
                this,
                location,
                force,
                index,
                platform_user_id,
                device_id,
            );
        };
        return false;
    }

    pub fn shouldSimulateGesture(
        this: *Self,
        gesture: GestureEvent,
        enable: bool,
    ) void {
        if (this.virtual) |v| if (v.shouldSimulateGesture) |f| {
            f(this, gesture, enable);
        };
    }

    pub fn onMotionDetected(
        this: *Self,
        tilt: math.Vector3(f32),
        rotation_rate: math.Vector3(f32),
        gravity: math.Vector3(f32),
        acceleration: math.Vector3(f32),
        platform_user_id: input_device_mapper.PlatformUserId,
        device_id: input_device_mapper.InputDeviceId,
    ) bool {
        if (this.virtual) |v| if (v.onMotionDetected) |f| {
            return f(
                this,
                tilt,
                rotation_rate,
                gravity,
                acceleration,
                platform_user_id,
                device_id,
            );
        };
        return false;
    }

    pub fn onSizeChanged(
        this: *Self,
        wnd: *GenericWindow,
        width: i32,
        height: i32,
        minimised: bool,
    ) bool {
        if (this.virtual) |v| if (v.onSizeChanged) |f| {
            return f(this, wnd, width, height, minimised);
        };
        return false;
    }

    pub fn onOsPaint(
        this: *Self,
        wnd: *GenericWindow,
    ) void {
        if (this.virtual) |v| if (v.onOsPaint) |f| {
            f(this, wnd);
        };
    }

    pub fn getSizeLimitsForWindow(
        this: *const Self,
        wnd: *GenericWindow,
    ) ?WindowSizeLimits {
        if (this.virtual) |v| if (v.getSizeLimitsForWindow) |f| {
            return f(this, wnd);
        };
        return null;
    }

    pub fn onResizingWindow(
        this: *Self,
        wnd: *GenericWindow,
    ) void {
        if (this.virtual) |v| if (v.onResizingWindow) |f| {
            f(this, wnd);
        };
    }

    pub fn beginReshapingWindow(
        this: *Self,
        wnd: *GenericWindow,
    ) bool {
        if (this.virtual) |v| if (v.beginReshapingWindow) |f| {
            return f(this, wnd);
        };
        return false;
    }

    pub fn finishedReshapingWindow(
        this: *Self,
        wnd: *GenericWindow,
    ) void {
        if (this.virtual) |v| if (v.finishedReshapingWindow) |f| {
            f(this, wnd);
        };
    }

    pub fn handleDpiScaleChanged(
        this: *Self,
        wnd: *GenericWindow,
    ) void {
        if (this.virtual) |v| if (v.handleDpiScaleChanged) |f| {
            f(this, wnd);
        };
    }

    pub fn signalSystemDpiChanged(
        this: *Self,
        wnd: *GenericWindow,
    ) void {
        if (this.virtual) |v| if (v.signalSystemDpiChanged) |f| {
            f(this, wnd);
        };
    }

    pub fn onMovedWindow(
        this: *Self,
        wnd: *GenericWindow,
        x: i32,
        y: i32,
    ) void {
        if (this.virtual) |v| if (v.onMovedWindow) |f| {
            f(this, wnd, x, y);
        };
    }

    pub fn onWindowActivationChanged(
        this: *Self,
        wnd: *GenericWindow,
        activation_type: WindowActivation,
    ) bool {
        if (this.virtual) |v| if (v.onWindowActivationChanged) |f| {
            return f(this, wnd, activation_type);
        };
        return false;
    }

    pub fn onApplicationActivationChanged(
        this: *Self,
        is_active: bool,
    ) bool {
        if (this.virtual) |v| if (v.onApplicationActivationChanged) |f| {
            return f(this, is_active);
        };
        return false;
    }

    pub fn onConvertibleLaptopModeChanged(
        this: *Self,
    ) bool {
        if (this.virtual) |v| if (v.onConvertibleLaptopModeChanged) |f| {
            return f(this);
        };
        return false;
    }

    pub fn getWindowZoneForPaint(
        this: *Self,
        wnd: *GenericWindow,
        x: i32,
        y: i32,
    ) WindowZone {
        if (this.virtual) |v| if (v.getWindowZoneForPaint) |f| {
            return f(this, wnd, x, y);
        };
        return WindowZone.not_in_window;
    }

    pub fn onWindowClose(
        this: *Self,
        wnd: *GenericWindow,
    ) void {
        if (this.virtual) |v| if (v.onWindowClose) |f| {
            return f(this, wnd);
        };
    }

    pub fn onDragEnterText(
        this: *Self,
        wnd: *GenericWindow,
        text: []const u8,
    ) DropEffect {
        if (this.virtual) |v| if (v.onDragEnterText) |f| {
            return f(this, wnd, text);
        };
        return DropEffect.none;
    }

    pub fn onDragEnterFiles(
        this: *Self,
        wnd: *GenericWindow,
        files: []const []const u8,
    ) DropEffect {
        if (this.virtual) |v| if (v.onDragEnterFiles) |f| {
            return f(this, wnd, files);
        };
        return DropEffect.none;
    }

    pub fn onDragEnterExternal(
        this: *Self,
        wnd: *GenericWindow,
        text: []const u8,
        files: []const []const u8,
    ) DropEffect {
        if (this.virtual) |v| if (v.onDragEnterExternal) |f| {
            return f(this, wnd, text, files);
        };
        return DropEffect.none;
    }

    pub fn onDragOver(
        this: *Self,
        wnd: *GenericWindow,
    ) DropEffect {
        if (this.virtual) |v| if (v.onDragOver) |f| {
            return f(this, wnd);
        };
        return DropEffect.none;
    }

    pub fn onDragLeave(
        this: *Self,
        wnd: *GenericWindow,
    ) void {
        if (this.virtual) |v| if (v.onDragLeave) |f| {
            f(this, wnd);
        };
    }

    pub fn onDragDrop(
        this: *Self,
        wnd: *GenericWindow,
    ) DropEffect {
        if (this.virtual) |v| if (v.onDragDrop) |f| {
            return f(this, wnd);
        };
        return DropEffect.none;
    }

    pub fn onWindowAction(
        this: *Self,
        wnd: *GenericWindow,
        action: WindowAction,
    ) bool {
        if (this.virtual) |v| if (v.onWindowAction) |f| {
            return f(this, wnd, action);
        };
        return false;
    }

    pub fn setCursorPos(
        this: *Self,
        pos: math.Vector2(f32),
    ) void {
        if (this.virtual) |v| if (v.setCursorPos) |f| {
            f(this, pos);
        };
    }
};
