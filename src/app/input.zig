const std = @import("std");

const app = @import("app.zig");
const math = @import("../math.zig");
const platform = @import("platform.zig");

pub const Input = struct {
    const MouseState = struct {
        buttons: [5]bool = .{false} ** 5,
        position: [2]i32 = .{ 0, 0 },
        scroll: i32 = 0,
        mode: MouseMode = .absolute,
    };

    allocator: std.mem.Allocator = undefined,
    platform_input: platform.impl.Input = .{},
    last_input_type: InputType = .touch,

    mutex: std.Thread.Mutex = .{},

    mouse_enabled: bool = false,
    touch_enabled: bool = false,
    keyboard_enabled: bool = false,
    gamepad_enabled: bool = false,

    mouse_state: MouseState = .{},

    has_focus: bool = false,

    focused_changed_callback: ?FocusedChangedCallback = null,
    input_began_callback: ?InputBeganCallback = null,
    input_changed_callback: ?InputChangedCallback = null,
    input_ended_callback: ?InputEndedCallback = null,
    touch_began_callback: ?TouchBeganCallback = null,
    touch_changed_callback: ?TouchChangedCallback = null,
    touch_ended_callback: ?TouchEndedCallback = null,
    input_type_updated_callback: ?InputTypeUpdatedCallback = null,
    frame_update_callback: ?FrameUpdateCallback = null,
    window_resized_callback: ?WindowResizedCallback = null,

    const FocusedChangedCallback = *const fn (*app.Window, bool) void;
    const InputBeganCallback = *const fn (InputObject) void;
    const InputChangedCallback = *const fn (InputObject) void;
    const InputEndedCallback = *const fn (InputObject) void;
    const TouchBeganCallback = *const fn (InputObject) void;
    const TouchChangedCallback = *const fn (InputObject) void;
    const TouchEndedCallback = *const fn (InputObject) void;
    const InputTypeUpdatedCallback = *const fn (new: InputType, old: InputType) void;
    const FrameUpdateCallback = *const fn (*app.Window) void;
    const WindowResizedCallback = *const fn (*app.Window, [2]u32) void;

    pub fn create(allocator: std.mem.Allocator) !*Input {
        var self: *Input = try allocator.create(Input);
        self.* = .{};
        errdefer allocator.destroy(self);
        try self.init(allocator);
        return self;
    }

    pub fn destroy(self: *Input) void {
        self.deinit();
        self.allocator.destroy(self);
    }

    pub fn init(self: *Input, allocator: std.mem.Allocator) !void {
        self.mouse_enabled = false;
        self.touch_enabled = false;
        self.keyboard_enabled = false;
        self.gamepad_enabled = false;
        switch (platform.this_platform) {
            .windows, .osx, .linux => {
                self.last_input_type = .mousemove;
                self.mouse_enabled = true;
                self.keyboard_enabled = true;
            },
            .ios, .android => {
                self.last_input_type = .touch;
                self.touch_enabled = true;
            },
            .xboxone, .ps4, .ps5, .@"switch" => {
                self.last_input_type = .gamepad;
                self.gamepad_enabled = true;
            },
            .none => {
                self.last_input_type = .none;
            },
            else => {},
        }
        self.allocator = allocator;

        try self.platform_input.init();
    }

    pub fn deinit(self: *Input) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.platform_input.deinit();
    }

    pub fn format(
        self: Input,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Input:\nmouse:{}\ntouch:{}\nkeyboard:{}\ngamepad:{}", .{
            self.mouse_enabled,
            self.touch_enabled,
            self.keyboard_enabled,
            self.gamepad_enabled,
        });
    }

    pub fn isTenFootInterface(self: *Input) bool {
        _ = self;
        switch (platform.this_platform) {
            .xboxone, .ps4, .ps5, .@"switch", .steamos => true,
            else => false,
        }
    }

    fn updateLastInputType(self: *Input, input_object: InputObject) void {
        if (self.last_input_type != input_object.type) {
            // we only update gamepad input type if it is of a minimum magnitude
            if (input_object.type == .gamepad and math.all(math.length3(input_object.position) < math.splat(math.Vec, 0.2), 0)) {
                return;
            }
            const old = self.last_input_type;
            self.last_input_type = input_object.type;
            if (self.input_type_updated_callback) |cb| {
                cb(input_object.type, old);
            }
        }
    }

    fn updateCurrentMousePosition(self: *Input, input_object: InputObject) void {
        if (input_object.type == .mousemove) {
            const rounded = @round(input_object.position);
            self.mouse_state.position[0] = @intFromFloat(rounded[0]);
            self.mouse_state.position[1] = @intFromFloat(rounded[1]);
        }
    }

    pub fn addEvent(self: *Input, input_object: InputObject, native_input_object: ?*void) !void {
        _ = native_input_object;

        if (!self.mutex.tryLock()) return;
        defer self.mutex.unlock();

        switch (input_object.input_state) {
            .begin => {
                if (self.input_began_callback) |cb| {
                    cb(input_object);
                }
                if (input_object.isTouch()) {
                    if (self.touch_began_callback) |cb| {
                        cb(input_object);
                    }
                }
            },
            .change => {
                if (self.input_changed_callback) |cb| {
                    cb(input_object);
                }
                if (input_object.isTouch()) {
                    if (self.touch_changed_callback) |cb| {
                        cb(input_object);
                    }
                }
            },
            .end => {
                if (self.input_ended_callback) |cb| {
                    cb(input_object);
                }
                if (input_object.isTouch()) {
                    if (self.touch_ended_callback) |cb| {
                        cb(input_object);
                    }
                }
            },
            .cancel => {},
        }
    }

    pub fn getMousePosition(self: *Input) [2]i32 {
        return self.current_mouse_position;
    }
};

// Definitions

pub const InputObject = struct {
    type: InputType,
    window: ?*app.Window = null,
    input_state: InputState = .begin,
    position: math.Vec = math.f32x4s(0),
    delta: math.Vec = math.f32x4s(0),
    modifiers: Modifiers = .{},
    data: union(InputType) {
        mousebutton: u8, // mouse button index
        mousewheel: void,
        mousemove: void,
        touch: u8, // touch id
        keyboard: KeyboardData,
        focus: void,
        accelerometer: void,
        gyro: void,
        gamepad: GamepadButton,
        textinput: union(enum) {
            short: u8,
            long: struct {
                allocator: std.mem.Allocator,
                text: []const u8,
            },
        },
    },

    pub fn deinit(self: *InputObject) void {
        switch (self.data) {
            .textinput => |ti| {
                if (ti == .long) {
                    ti.long.allocator.free(ti.long.text);
                }
            },
            else => {},
        }
    }

    pub fn isTouch(self: InputObject) bool {
        return self.type == .touch;
    }

    pub fn isMouse(self: InputObject) bool {
        return self.type == .mousebutton or self.type == .mousewheel or self.type == .mousemove;
    }

    pub fn isKeyboard(self: InputObject) bool {
        return self.type == .keyboard;
    }

    pub fn isGamepad(self: InputObject) bool {
        return self.type == .gamepad;
    }
};

pub const KeyboardData = struct {
    scancode: ScanCode,
    keycode: KeyCode,
    down: bool,
};

pub const InputType = enum(u8) {
    mousebutton,
    mousewheel,
    mousemove,
    touch,
    keyboard,
    focus,
    accelerometer,
    gyro,
    gamepad,
    textinput,
};

pub const WrapMode = enum(u8) {
    auto,
    center,
    hybrid,
    none_and_center,
    none,
};

const MouseMode = enum {
    absolute,
    relative,
};

pub const InputState = enum(u8) {
    begin = 0,
    change = 1,
    end = 2,
    cancel = 3,
};

// Taken from SDL
//
// Copyright (C) 1997-2023 Sam Lantinga <slouken@libsdl.org>

// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.

// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:

// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
// 3. This notice may not be removed or altered from any source distribution.

pub const ScanCode = u8;
pub const KeyCode = enum(u16) {
    unknown = 0,
    backspace = 8,
    tab = 9,
    clear = 12,
    @"return" = 13,
    pause = 19,
    escape = 27,
    space = 32,
    exclaim = 33,
    quotedbl = 34,
    hash = 35,
    dollar = 36,
    percent = 37,
    ampersand = 38,
    quote = 39,
    leftparen = 40,
    rightparen = 41,
    asterisk = 42,
    plus = 43,
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
    colon = 58,
    semicolon = 59,
    less = 60,
    equals = 61,
    greater = 62,
    question = 63,
    at = 64,
    // Skip uppercase letters
    leftbracket = 91,
    backslash = 92,
    rightbracket = 93,
    caret = 94,
    underscore = 95,
    backquote = 96,
    a = 97,
    b = 98,
    c = 99,
    d = 100,
    e = 101,
    f = 102,
    g = 103,
    h = 104,
    i = 105,
    j = 106,
    k = 107,
    l = 108,
    m = 109,
    n = 110,
    o = 111,
    p = 112,
    q = 113,
    r = 114,
    s = 115,
    t = 116,
    u = 117,
    v = 118,
    w = 119,
    x = 120,
    y = 121,
    z = 122,

    leftcurly = 123,
    pipe = 124,
    rightcurly = 125,
    tilde = 126,
    delete = 127,
    // End of ASCII mapped keysyms

    // International keyboard syms
    world_0 = 160, // 0xA0
    world_1 = 161,
    world_2 = 162,
    world_3 = 163,
    world_4 = 164,
    world_5 = 165,
    world_6 = 166,
    world_7 = 167,
    world_8 = 168,
    world_9 = 169,
    world_10 = 170,
    world_11 = 171,
    world_12 = 172,
    world_13 = 173,
    world_14 = 174,
    world_15 = 175,
    world_16 = 176,
    world_17 = 177,
    world_18 = 178,
    world_19 = 179,
    world_20 = 180,
    world_21 = 181,
    world_22 = 182,
    world_23 = 183,
    world_24 = 184,
    world_25 = 185,
    world_26 = 186,
    world_27 = 187,
    world_28 = 188,
    world_29 = 189,
    world_30 = 190,
    world_31 = 191,
    world_32 = 192,
    world_33 = 193,
    world_34 = 194,
    world_35 = 195,
    world_36 = 196,
    world_37 = 197,
    world_38 = 198,
    world_39 = 199,
    world_40 = 200,
    world_41 = 201,
    world_42 = 202,
    world_43 = 203,
    world_44 = 204,
    world_45 = 205,
    world_46 = 206,
    world_47 = 207,
    world_48 = 208,
    world_49 = 209,
    world_50 = 210,
    world_51 = 211,
    world_52 = 212,
    world_53 = 213,
    world_54 = 214,
    world_55 = 215,
    world_56 = 216,
    world_57 = 217,
    world_58 = 218,
    world_59 = 219,
    world_60 = 220,
    world_61 = 221,
    world_62 = 222,
    world_63 = 223,
    world_64 = 224,
    world_65 = 225,
    world_66 = 226,
    world_67 = 227,
    world_68 = 228,
    world_69 = 229,
    world_70 = 230,
    world_71 = 231,
    world_72 = 232,
    world_73 = 233,
    world_74 = 234,
    world_75 = 235,
    world_76 = 236,
    world_77 = 237,
    world_78 = 238,
    world_79 = 239,
    world_80 = 240,
    world_81 = 241,
    world_82 = 242,
    world_83 = 243,
    world_84 = 244,
    world_85 = 245,
    world_86 = 246,
    world_87 = 247,
    world_88 = 248,
    world_89 = 249,
    world_90 = 250,
    world_91 = 251,
    world_92 = 252,
    world_93 = 253,
    world_94 = 254,
    world_95 = 255, // 0xFF

    // Numeric keypad
    kp0 = 256,
    kp1 = 257,
    kp2 = 258,
    kp3 = 259,
    kp4 = 260,
    kp5 = 261,
    kp6 = 262,
    kp7 = 263,
    kp8 = 264,
    kp9 = 265,
    kp_period = 266,
    kp_divide = 267,
    kp_multiply = 268,
    kp_minus = 269,
    kp_plus = 270,
    kp_enter = 271,
    kp_equals = 272,

    // Arrows + Home/End pad
    up = 273,
    down = 274,
    right = 275,
    left = 276,
    insert = 277,
    home = 278,
    end = 279,
    pageup = 280,
    pagedown = 281,

    // Function keys
    f1 = 282,
    f2 = 283,
    f3 = 284,
    f4 = 285,
    f5 = 286,
    f6 = 287,
    f7 = 288,
    f8 = 289,
    f9 = 290,
    f10 = 291,
    f11 = 292,
    f12 = 293,
    f13 = 294,
    f14 = 295,
    f15 = 296,

    // Key state modifier keys
    numlock = 300,
    capslock = 301,
    scrollock = 302,
    rshift = 303,
    lshift = 304,
    rctrl = 305,
    lctrl = 306,
    ralt = 307,
    lalt = 308,
    rmeta = 309,
    lmeta = 310,
    lsuper = 311, // Left "Windows" key
    rsuper = 312, // Right "Windows" key
    mode = 313, // "Alt Gr" key
    compose = 314, // Multi-key compose key

    // Miscellaneous function keys
    help = 315,
    print = 316,
    sysreq = 317,
    @"break" = 318,
    menu = 319,
    power = 320, // Power Macintosh power key
    euro = 321, // Some european keyboards
    undo = 322, // Atari keyboard has Undo

    // Add any other keys here
};

pub const GamepadButton = enum(u8) {
    buttonx = 0,
    buttony = 1,
    buttona = 2,
    buttonb = 3,
    buttonr1 = 4,
    buttonl1 = 5,
    buttonr2 = 6,
    buttonl2 = 7,
    buttonr3 = 8,
    buttonl3 = 9,
    buttonstart = 10,
    buttonselect = 11,
    dpadleft = 12,
    dpadright = 13,
    dpadup = 14,
    dpaddown = 15,
    thumbstick1 = 16,
    thumbstick2 = 17,
};

pub const Modifiers = packed struct {
    lshift: bool = false,
    rshift: bool = false,
    lctrl: bool = false,
    rctrl: bool = false,
    lalt: bool = false,
    ralt: bool = false,
    lmeta: bool = false,
    rmeta: bool = false,
    num: bool = false,
    caps: bool = false,
    mode: bool = false,
};
