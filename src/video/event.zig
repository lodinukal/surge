const std = @import("std");

const platform = @import("./platform_impl/platform_impl.zig");
const dpi = @import("dpi.zig");
const keyboard = @import("keyboard.zig");
const theme = @import("theme.zig");

pub fn Event(comptime T: type) type {
    return union(enum) {
        new_events: StartCause,
        window_event: struct {
            window_id: platform.impl.WindowId,
            event: WindowEvent,
        },
        device_event: struct {
            device_id: DeviceId,
            event: DeviceEvent,
        },
        user_event: T,
        suspended,
        resumed,
        about_to_wait,
        redraw_requested: platform.impl.WindowId,
        loop_exiting,
    };
}

pub const StartCause = union(enum) {
    resume_time_reached: struct {
        start: std.time.Instant,
        requested_resume: std.time.Instant,
    },
    wait_cancelled: struct {
        start: std.time.Instant,
        requested_resume: std.time.Instant,
    },
    poll,
    init,
};

pub const WindowEvent = union(enum) {
    // activation_token_done,
    resized: dpi.PhysicalSize,
    moved: dpi.PhysicalPosition,
    close_requested,
    destroyed,
    dropped_file: []u8,
    hovered_file: []u8,
    hovered_file_cancelled,
    focused: bool,
    keyboard_input: struct {
        device_id: DeviceId,
        event: KeyEvent,
        is_synthetic: bool,
    },
    modifiers_changed: Modifiers,
    ime: Ime,
    cursor_moved: struct {
        device_id: DeviceId,
        position: dpi.PhysicalSize,
    },
    cursor_entered: DeviceId,
    cursor_left: DeviceId,
    mouse_wheel: struct {
        device_id: DeviceId,
        delta: MouseScrollDelta,
        phase: TouchPhase,
    },
    mouse_input: struct {
        device_id: DeviceId,
        state: ElementState,
        button: MouseButton,
    },
    touchpad_magnify: struct { device_id: DeviceId, delta: f64, phase: TouchPhase },
    smart_magnify: DeviceId,
    touchpad_rotate: struct { device_id: DeviceId, delta: f32, phase: TouchPhase },
    touchpad_pressure: struct {
        device_id: DeviceId,
        pressure: f32,
        stage: i64,
    },
    axis_motion: struct {
        device_id: DeviceId,
        axis: AxisId,
        value: f64,
    },
    touch: Touch,
    scale_factor_changed: struct {
        scale_factor: f64,
        inner_size_writer: InnerSizeWriter,
    },
    theme_changed: theme.Theme,
    occluded: bool,
};

pub const DeviceId = struct {
    platform_device_id: platform.impl.DeviceId,

    pub fn dummy() DeviceId {
        return DeviceId{
            .platform_device_id = platform.impl.DeviceId.dummy(),
        };
    }
};

pub const DeviceEvent = union(enum) {
    added,
    removed,

    mouse_motion: struct {
        delta: struct { f64, f64 },
    },
    mouse_wheel: struct {
        delta: MouseScrollDelta,
    },
    motion: struct {
        axis: AxisId,
        value: f64,
    },
    button: struct {
        button: ButtonId,
        state: ElementState,
    },
    key: RawKeyEvent,
    text: struct {
        codepoint: u8,
    },
};

pub const RawKeyEvent = struct {
    physical_key: keyboard.KeyCode,
    state: ElementState,
};

pub const KeyEvent = struct {
    physical_key: keyboard.KeyCode,
    text: ?[]const u8,
    location: keyboard.KeyLocation,
    state: ElementState,
    repeat: bool,
    platform_specific: platform.impl.KeyEventExtra,
};

pub const Modifiers = struct {
    state: keyboard.ModifiersState,
    pressed_mods: keyboard.ModifiersKeys,

    pub fn getState(self: Modifiers) keyboard.ModifiersState {
        return self.state;
    }

    pub fn getLShift(self: Modifiers) bool {
        return self.modState(keyboard.ModifiersKeys.lshift);
    }

    pub fn getRShift(self: Modifiers) bool {
        return self.modState(keyboard.ModifiersKeys.rshift);
    }

    pub fn getLCtrl(self: Modifiers) bool {
        return self.modState(keyboard.ModifiersKeys.lctrl);
    }

    pub fn getRCtrl(self: Modifiers) bool {
        return self.modState(keyboard.ModifiersKeys.rctrl);
    }

    pub fn getLAlt(self: Modifiers) bool {
        return self.modState(keyboard.ModifiersKeys.lalt);
    }

    pub fn getRAlt(self: Modifiers) bool {
        return self.modState(keyboard.ModifiersKeys.ralt);
    }

    pub fn getLSuper(self: Modifiers) bool {
        return self.modState(keyboard.ModifiersKeys.lsuper);
    }

    pub fn getRSuper(self: Modifiers) bool {
        return self.modState(keyboard.ModifiersKeys.rsuper);
    }

    fn modState(self: Modifiers, mod: keyboard.ModifiersKeys) keyboard.ModifiersKeyState {
        return if ((self.pressed_mods & mod) != 0)
            keyboard.ModifiersKeyState.pressed
        else
            keyboard.ModifiersKeyState.unknown;
    }
};

pub const Ime = union(enum) {
    enabled,
    pre_edit: struct { []u8, ?struct { usize, usize } },
    commit: []u8,
    disabled,
};

pub const TouchPhase = enum {
    started,
    moved,
    ended,
    cancelled,
};

pub const Touch = struct {
    device_id: DeviceId,
    phase: TouchPhase,
    location: dpi.PhysicalPosition,
    force: ?Force,
    id: u64,
};

pub const Force = union(enum) {
    calibrated: struct {
        force: f64,
        max_possible_force: f64,
        altitude_angle: ?f64,
    },
    normalised: f64,

    pub fn normalised(f: Force) f64 {
        switch (f) {
            .calibrated => |calibrated| {
                if (calibrated.altitude_angle) |angle| {
                    return calibrated.force / @sin(angle);
                }
                return calibrated.force / calibrated.max_possible_force;
            },
            .normalised => |normalised_value| return normalised_value,
        }
    }
};

pub const AxisId = u32;

pub const ButtonId = u32;

pub const ElementState = enum {
    pressed,
    released,

    pub fn isPressed(self: ElementState) bool {
        return self == ElementState.pressed;
    }
};

pub const MouseButton = union(enum) {
    left,
    right,
    middle,
    back,
    forward,
    other: u16,
};

pub const MouseScrollDelta = union(enum) {
    line_delta: struct { f32, f32 },
    pixel_delta: dpi.PhysicalPosition,
};

pub const InnerSizeWriter = struct {
    pub const InnerSizeType = struct { size: dpi.PhysicalSize, mutex: std.Thread.Mutex };
    new_inner_size: ?*InnerSizeType,

    pub fn init(new_inner_size: ?*InnerSizeType) InnerSizeWriter {
        return InnerSizeWriter{
            .new_inner_size = new_inner_size,
        };
    }

    pub fn request_inner_size(isw: *InnerSizeWriter, size: dpi.PhysicalSize) !void {
        if (isw.new_inner_size) |new_inner_size| {
            new_inner_size.mutex.lock();
            defer new_inner_size.mutex.unlock();
            new_inner_size.size = size;
        } else {
            return error.Ignored;
        }
    }
};
