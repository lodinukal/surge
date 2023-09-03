pub const std = @import("std");

pub const ElementState = enum(u8) {
    release = 0,
    press = 1,
    repeat = 2,
    stick = 3,
};

pub const Hat = enum(u8) {
    centred = 0,
    up = 1,
    right = 2,
    down = 4,
    left = 8,
    pub const right_up = Hat.right | Hat.up;
    pub const right_down = Hat.right | Hat.down;
    pub const left_up = Hat.left | Hat.up;
    pub const left_down = Hat.left | Hat.down;
};

pub const Key = enum(i16) {
    unknown = -1,
    space = 32,
    apostrophe = 39,
    comma = 44,
    minus = 45,
    period = 46,
    slash = 47,
    @"0" = 48,
    @"1" = 49,
    @"2" = 50,
    @"3" = 51,
    @"4" = 52,
    @"5" = 53,
    @"6" = 54,
    @"7" = 55,
    @"8" = 56,
    @"9" = 57,
    semicolon = 59,
    equal = 61,
    a = 65,
    b = 66,
    c = 67,
    d = 68,
    e = 69,
    f = 70,
    g = 71,
    h = 72,
    i = 73,
    j = 74,
    k = 75,
    l = 76,
    m = 77,
    n = 78,
    o = 79,
    p = 80,
    q = 81,
    r = 82,
    s = 83,
    t = 84,
    u = 85,
    v = 86,
    w = 87,
    x = 88,
    y = 89,
    z = 90,
    left_bracket = 91,
    backslash = 92,
    right_bracket = 93,
    grave_accent = 96,
    world_1 = 161,
    world_2 = 162,

    escape = 256,
    enter = 257,
    tab = 258,
    backspace = 259,
    insert = 260,
    delete = 261,
    right = 262,
    left = 263,
    down = 264,
    up = 265,
    page_up = 266,
    page_down = 267,
    home = 268,
    end = 269,
    caps_lock = 280,
    scroll_lock = 281,
    num_lock = 282,
    print_screen = 283,
    pause = 284,
    f1 = 290,
    f2 = 291,
    f3 = 292,
    f4 = 293,
    f5 = 294,
    f6 = 295,
    f7 = 296,
    f8 = 297,
    f9 = 298,
    f10 = 299,
    f11 = 300,
    f12 = 301,
    f13 = 302,
    f14 = 303,
    f15 = 304,
    f16 = 305,
    f17 = 306,
    f18 = 307,
    f19 = 308,
    f20 = 309,
    f21 = 310,
    f22 = 311,
    f23 = 312,
    f24 = 313,
    f25 = 314,
    kp_0 = 320,
    kp_1 = 321,
    kp_2 = 322,
    kp_3 = 323,
    kp_4 = 324,
    kp_5 = 325,
    kp_6 = 326,
    kp_7 = 327,
    kp_8 = 328,
    kp_9 = 329,
    kp_decimal = 330,
    kp_divide = 331,
    kp_multiply = 332,
    kp_subtract = 333,
    kp_add = 334,
    kp_enter = 335,
    kp_equal = 336,
    left_shift = 340,
    left_control = 341,
    left_alt = 342,
    left_super = 343,
    right_shift = 344,
    right_control = 345,
    right_alt = 346,
    right_super = 347,
    menu = 348,
};

pub const Modifier = enum(u8) {
    shift = 0x0001,
    control = 0x0002,
    alt = 0x0004,
    super = 0x0008,
    caps_lock = 0x0010,
    num_lock = 0x0020,
};

pub const Modifiers = packed struct(u8) {
    shift: bool = false,
    control: bool = false,
    alt: bool = false,
    super: bool = false,
    caps_lock: bool = false,
    num_lock: bool = false,
    _padding: u2 = 0,
};

pub const MouseButton = enum(u8) {
    @"1" = 0,
    @"2" = 1,
    @"3" = 2,
    @"4" = 3,
    @"5" = 4,
    @"6" = 5,
    @"7" = 6,
    @"8" = 7,
    pub const left = MouseButton.@"1";
    pub const right = MouseButton.@"2";
    pub const middle = MouseButton.@"3";
};

pub const Joystick = enum(u8) {
    @"1" = 0,
    @"2" = 1,
    @"3" = 2,
    @"4" = 3,
    @"5" = 4,
    @"6" = 5,
    @"7" = 6,
    @"8" = 7,
    @"9" = 8,
    @"10" = 9,
    @"11" = 10,
    @"12" = 11,
    @"13" = 12,
    @"14" = 13,
    @"15" = 14,
    @"16" = 15,
};

pub const GamepadButton = enum(u8) {
    a = 0,
    b = 1,
    x = 2,
    y = 3,
    left_bumper = 4,
    right_bumper = 5,
    back = 6,
    start = 7,
    guide = 8,
    left_thumb = 9,
    right_thumb = 10,
    d_pad_up = 11,
    d_pad_right = 12,
    d_pad_down = 13,
    d_pad_left = 14,

    pub const cross = GamepadButton.a;
    pub const circle = GamepadButton.b;
    pub const square = GamepadButton.x;
    pub const triangle = GamepadButton.y;
};

pub const GamepadAxis = enum(u8) {
    left_x = 0,
    left_y = 1,
    right_x = 2,
    right_y = 3,
    left_trigger = 4,
    right_trigger = 5,
};

pub const Error = error{
    NotInitialised,
    OutOfMemory,
    Unavailable,
    PlatformError,
    FormatUnavailable,
    CursorShapeUnavailable,
    FeatureUnavailable,
    Unimplemented,
    PlatformUnavailable,
};

pub const WindowFlags = packed struct {
    focused: bool = false,
    iconified: bool = false,
    resizable: bool = true,
    visible: bool = true,
    decorated: bool = true,
    auto_iconify: bool = true,
    floating: bool = false,
    maximised: bool = false,
    centre_cursor: bool = true,
    transparent_framebuffer: bool = false,
    hovered: bool = false,
    focus_on_show: bool = true,
    mouse_passthrough: bool = false,
    initial_position: ?struct { i32, i32 },
};

pub const CursorShape = enum {
    cursor,
    ibeam,
    crosshair,
    pointing_hand,
    resize_ew,
    resize_ns,
    resize_nwse,
    resize_nesw,
    resize_all,
    not_allowed,
    hresize,
    vresize,
    hand_cursor,
};

pub const VideoMode = struct {
    width: i32,
    height: i32,
    red_bits: i32,
    green_bits: i32,
    blue_bits: i32,
    refresh_rate: i32,
};

pub const GammaRamp = struct {
    red: []const u16,
    green: []const u16,
    blue: []const u16,
};

pub const Image = struct {
    width: i32,
    height: i32,
    pixels: []const u8,
};

pub const GamepadState = struct {
    buttons: [std.meta.fields(GamepadButton).len]ElementState,
    axes: [std.meta.fields(GamepadAxis).len]f32,
};

pub const InputMode = enum {
    cursor,
    sticky_keys,
    sticky_mouse_buttons,
    lock_key_mods,
    raw_mouse_motion,
};

pub const InputModePayload = union(InputMode) {
    cursor: CursorMode,
    sticky_keys: bool,
    sticky_mouse_buttons: bool,
    lock_key_mods: bool,
    raw_mouse_motion: bool,
};

pub const CursorMode = enum {
    normal,
    hidden,
    disabled,
    captured,
};
