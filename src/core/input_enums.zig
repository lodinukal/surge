pub const MouseButton = enum(u16) {
    none = 0,
    left = 1,
    right = 2,
    middle = 3,
    wheel_up = 4,
    wheel_down = 5,
    wheel_left = 6,
    wheel_right = 7,
    x1 = 8,
    x2 = 9,
};

pub const MouseButtonState = packed struct(u8) {
    left: bool = false,
    right: bool = false,
    middle: bool = false,
    x1: bool = false,
    x2: bool = false,
    _padding: u3 = undefined,
};
