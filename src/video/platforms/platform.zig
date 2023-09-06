const std = @import("std");
const definitions = @import("../definitions.zig");

const main = @import("../main.zig");
const common = @import("../../core/common.zig");

const monitor = @import("../monitor.zig");
const window = @import("../window.zig");
const input = @import("../input.zig");
const joystick = @import("../joystick.zig");
const Cursor = @import("../cursor.zig").Cursor;

const builtin = @import("builtin");
pub const impl = switch (builtin.os.tag) {
    .windows => @import("./windows/platform.zig"),
    inline else => @compileError("Unsupported OS"),
};

pub const Poll = enum {
    presence,
    axes,
    buttons,
    all, // axes | buttons
};

pub const InternalWindowConfig = struct {
    xpos: i32,
    ypos: i32,
    width: i32,
    height: i32,
    title: []const u8,
    resizable: bool,
    decorated: bool,
    focused: bool,
    auto_iconify: bool,
    floating: bool,
    maximized: bool,
    center_cursor: bool,
    focus_on_show: bool,
    mouse_passthrough: bool,
    scale_to_monitor: bool,
    ns: struct {
        retina: bool,
        frame_name: [256]u8,
    },
    x11: struct {
        class_name: [256]u8,
        instance_name: [256]u8,
    },
    windows: struct {
        keymenu: bool,
    },
    wl: struct {
        app_id: [256]u8,
    },
};

pub const InternalFramebufferConfig = struct {
    red_bits: i32,
    green_bits: i32,
    blue_bits: i32,
    alpha_bits: i32,
    depth_bits: i32,
    stencil_bits: i32,
    accum_red_bits: i32,
    accum_green_bits: i32,
    accum_blue_bits: i32,
    accum_alpha_bits: i32,
    aux_buffers: i32,
    stereo: bool,
    samples: i32,
    srgb: bool,
    doublebuffer: bool,
    transparent: bool,
    handle: usize,
};

pub const InternalWindow = struct {
    next_window: ?*InternalWindow,
    resizable: bool,
    decorated: bool,
    auto_iconify: bool,
    floating: bool,
    focus_on_show: bool,
    mouse_passthrough: bool,
    should_close: bool,
    user_pointer: *void,
    double_buffer: bool,
    video_mode: definitions.VideoMode,
    monitor: *monitor.Monitor,
    cursor: ?*Cursor = null,
    min_width: i32,
    min_height: i32,
    max_width: i32,
    max_height: i32,
    numer: i32,
    denom: i32,
    sticky_keys: bool,
    sticky_mouse_buttons: bool,
    lock_key_mods: bool,
    cursor_mode: definitions.CursorMode,
    mouse_buttons: [
        std.meta.fields(definitions.MouseButton).len + 1
    ]definitions.ElementState,
    keys: [
        std.meta.fields(definitions.Key).len
    ]definitions.ElementState,
    virtual_cursor_pos_x: f64,
    virtual_cursor_pos_y: f64,
    raw_mouse_motion: bool,
    callbacks: struct {
        pos: ?window.WindowPosCallback,
        size: ?window.WindowSizeCallback,
        close: ?window.WindowCloseCallback,
        refresh: ?window.WindowRefreshCallback,
        focus: ?window.WindowFocusCallback,
        iconify: ?window.WindowIconifyCallback,
        maximise: ?window.WindowMaximiseCallback,
        framebuffer_changed: ?window.WindowFramebufferChangedCallback,
        content_scale: ?window.WindowContentScaleCallback,
        mouse_button: ?input.WindowMouseButtonCallback,
        cursor_pos: ?input.WindowCursorPosCallback,
        cursor_enter: ?input.WindowCursorEnterCallback,
        scroll: ?input.WindowScrollCallback,
        key: ?input.WindowKeyCallback,
        char: ?input.WindowCharCallback,
        char_mods: ?input.WindowCharModsCallback,
        drop: ?input.WindowDropCallback,
    },
    platform: impl.PlatformWindow,
};

pub const InternalMonitor = struct {
    name: [128]u8,
    user_pointer: *void,
    width_mm: i32,
    height_mm: i32,
    current_window: ?*InternalWindow = null,
    modes: std.ArrayListUnmanaged(definitions.VideoMode) = std.ArrayListUnmanaged(definitions.VideoMode){},
    current_mode: ?definitions.VideoMode = null,
    original_ramp: ?definitions.GammaRamp = null,
    current_ramp: ?definitions.GammaRamp = null,
    platform: impl.PlatformMonitor,
};

pub const InternalCursor = struct {
    next_cursor: ?*InternalCursor,
    platform: impl.PlatformCursor,
};

pub const JoystickMappingSource = enum(u8) {
    unknown = 0,
    axis = 1,
    button = 2,
    hatbit = 3,
};

pub const InternalMapElement = struct {
    typ: JoystickMappingSource = .unknown,
    index: u8 = 0,
    axis_scale: i8 = 0,
    axis_offset: i8 = 0,
};

pub const InternalMapping = struct {
    name: [128]u8 = .{0} ** 128,
    guid: [128]u8 = .{0} ** 128,
    buttons: [15]InternalMapElement = .{InternalMapElement{}} ** 15,
    axes: [6]InternalMapElement = .{InternalMapElement{}} ** 6,
    platform: impl.PlatformJoystick,
};

pub const InternalJoystick = struct {
    allocated: bool = false,
    connected: bool = false,
    axes: []f32 = undefined,
    buttons: []definitions.ElementState = undefined,
    hats: []u8 = undefined,
    name: [128]u8 = undefined,
    user_pointer: ?*void = null,
    guid: [32]u8 = undefined,
    mapping: ?*InternalMapping = null,

    platform: impl.PlatformJoystick = undefined,
};

pub const InternalPlatform = struct {
    platform_tag: std.Target.Os.Tag,

    init: fn () definitions.Error!void,
    deinit: fn () void,

    getCursorPos: fn (wnd: *InternalWindow) struct { x: f64, y: f64 },
    setCursorPos: fn (wnd: *InternalWindow, x: f64, y: f64) void,
    setCursorMode: fn (wnd: *InternalWindow, mode: definitions.CursorMode) void,
    setRawMouseMotion: fn (wnd: *InternalWindow, enabled: bool) void,
    isRawMouseMotionSupported: fn () bool,
    createCursor: fn (cursor: *InternalCursor, image: *definitions.Image, xhot: i32, yhot: i32) bool,
    createStandardCursor: fn (cursor: *InternalCursor, shape: definitions.CursorShape) bool,
    destroyCursor: fn (cursor: *InternalCursor) void,
    setCursor: fn (wnd: *InternalWindow, cursor: *InternalCursor) void,
    getScancodeName: fn (scancode: i32) ?[]const u8,
    getKeyScancode: fn (key: definitions.Key) i32,
    setClipboardString: fn (string: []const u8) void,
    getClipboardString: fn () ?[]const u8,
    initJoysticks: fn () bool,
    deinitJoysticks: fn () void,
    pollJoystick: fn (joy: *InternalJoystick, poll: Poll) bool,
    getMappingName: fn () []const u8,
    updateGamepadGuid: fn (n: []u8) void,

    freeMonitor: fn (monitor: *InternalMonitor) void,
    getMonitorPos: fn (monitor: *InternalMonitor) struct { x: i32, y: i32 },
    getMonitorContentScale: fn (monitor: *InternalMonitor) struct { x: f32, y: f32 },
    getMonitorWorkarea: fn (monitor: *InternalMonitor) struct { x: i32, y: i32, width: i32, height: i32 },
    getVideoModes: fn (monitor: *InternalMonitor) ?[]definitions.VideoMode,
    getVideoMode: fn (monitor: *InternalMonitor) *const definitions.VideoMode,
    getGammaRamp: fn (monitor: *InternalMonitor) ?definitions.GammaRamp,
    setGammaRamp: fn (monitor: *InternalMonitor, ramp: *const definitions.GammaRamp) void,

    createWindow: fn (cfg: *const InternalWindowConfig, fbcfg: *const InternalFramebufferConfig) ?*InternalWindow,
    destroyWindow: fn (wnd: *InternalWindow) void,
    setWindowTitle: fn (wnd: *InternalWindow, title: []const u8) void,
    setWindowIcon: fn (wnd: *InternalWindow, img: *const definitions.Image) void,
    getWindowPos: fn (wnd: *InternalWindow) struct { x: i32, y: i32 },
    setWindowPos: fn (wnd: *InternalWindow, xpos: i32, ypos: i32) void,
    getWindowSize: fn (wnd: *InternalWindow) struct { width: i32, height: i32 },
    setWindowSize: fn (wnd: *InternalWindow, width: i32, height: i32) void,
    setWindowSizeLimits: fn (wnd: *InternalWindow, minwidth: i32, minheight: i32, maxwidth: i32, maxheight: i32) void,
    setWindowAspectRatio: fn (wnd: *InternalWindow, numer: i32, denom: i32) void,
    getFramebufferSize: fn (wnd: *InternalWindow) struct { width: i32, height: i32 },
    getWindowFrameSize: fn (wnd: *InternalWindow) struct { left: i32, top: i32, right: i32, bottom: i32 },
    getWindowContentScale: fn (wnd: *InternalWindow) struct { x: f32, y: f32 },
    iconifyWindow: fn (wnd: *InternalWindow) void,
    restoreWindow: fn (wnd: *InternalWindow) void,
    maximizeWindow: fn (wnd: *InternalWindow) void,
    showWindow: fn (wnd: *InternalWindow) void,
    hideWindow: fn (wnd: *InternalWindow) void,
    requestWindowAttention: fn (wnd: *InternalWindow) void,
    focusWindow: fn (wnd: *InternalWindow) void,
    setWindowMonitor: fn (
        wnd: *InternalWindow,
        monitor: *InternalMonitor,
        xpos: i32,
        ypos: i32,
        width: i32,
        height: i32,
        refresh_rate: i32,
    ) void,
    isWindowFocused: fn (wnd: *InternalWindow) bool,
    isWindowIconified: fn (wnd: *InternalWindow) bool,
    isWindowVisible: fn (wnd: *InternalWindow) bool,
    isWindowMaximized: fn (wnd: *InternalWindow) bool,
    isWindowHovered: fn (wnd: *InternalWindow) bool,
    isFramebufferTransparent: fn (wnd: *InternalWindow) bool,
    getWindowOpacity: fn (wnd: *InternalWindow) f32,
    setWindowResizable: fn (wnd: *InternalWindow, resizable: bool) void,
    setWindowDecorated: fn (wnd: *InternalWindow, decorated: bool) void,
    setWindowFloating: fn (wnd: *InternalWindow, floating: bool) void,
    setWindowOpacity: fn (wnd: *InternalWindow, opacity: f32) void,
    setWindowMousePassthrough: fn (wnd: *InternalWindow, passthrough: bool) void,
    pollEvents: fn () void,
    waitEvents: fn () void,
    waitEventsTimeout: fn (timeout: f64) void,
    postEmptyEvent: fn () void,
};

pub const InternalLibrary = struct {
    initialised: bool = false,
    allocator: std.mem.Allocator,
    platform: InternalPlatform,
    cursor_head: ?*InternalCursor,
    window_head: ?*InternalWindow,
    monitors: std.ArrayListUnmanaged(*InternalMonitor) = std.ArrayListUnmanaged(*InternalMonitor){},
    joysticks_initialised: bool = false,
    joysticks: [std.meta.fields(definitions.Joystick).len]InternalJoystick,
    mappings: std.ArrayListUnmanaged(InternalMapping) = std.ArrayListUnmanaged(InternalMapping){},
    timer: struct {
        offset: u64,
        platform: impl.PlatformTimer,
    },

    callbacks: struct {
        joystick: joystick.JoystickConnectionCallback,
        monitor: monitor.MonitorConnectionCallback,
    },

    platform_state: impl.PlatformState,
    platform_joystick_state: impl.PlatformJoystickState,
};

pub var lib = InternalLibrary{};

pub fn initTimer() void {
    lib.timer.platform.init();
}
pub fn getTimerValue() u64 {
    return lib.timer.platform.getTimerValue();
}
pub fn getTimerFrequency() u64 {
    return lib.timer.platform.getTimerFrequency();
}

pub fn inputWindowFocus(wnd: *InternalWindow, focused: bool) void {
    if (wnd.callbacks.focus) |f| {
        f(@ptrCast(wnd), focused);
    }

    if (!focused) {
        inline for (std.meta.fields(definitions.Key)) |k| {
            if (wnd.keys[@intCast(k.value)] == definitions.ElementState.press) {
                const scancode = lib.platform.getKeyScancode(
                    @field(definitions.Key, k.name),
                );
                inputKey(
                    wnd,
                    scancode,
                    @enumFromInt(k.value),
                    definitions.ElementState.release,
                    0,
                );
            }
        }
        inline for (std.meta.fields(definitions.MouseButton)) |b| {
            if (wnd.mouse_buttons[@intCast(b.value)] == definitions.ElementState.press) {
                inputMouseClick(wnd, @enumFromInt(b.value), .release, 0);
            }
        }
    }
}

pub fn inputWindowPos(wnd: *InternalWindow, xpos: i32, ypos: i32) void {
    if (wnd.callbacks.pos) |f| {
        f(@ptrCast(wnd), xpos, ypos);
    }
}

pub fn inputWindowSize(wnd: *InternalWindow, width: i32, height: i32) void {
    if (wnd.callbacks.size) |f| {
        f(@ptrCast(wnd), width, height);
    }
}

pub fn inputFramebufferSize(wnd: *InternalWindow, width: i32, height: i32) void {
    if (wnd.callbacks.framebuffer_changed) |f| {
        f(@ptrCast(wnd), width, height);
    }
}

pub fn inputWindowContentScale(wnd: *InternalWindow, xscale: f32, yscale: f32) void {
    if (wnd.callbacks.content_scale) |f| {
        f(@ptrCast(wnd), xscale, yscale);
    }
}

pub fn inputWindowIconify(wnd: *InternalWindow, iconified: bool) void {
    if (wnd.callbacks.iconify) |f| {
        f(@ptrCast(wnd), iconified);
    }
}

pub fn inputWindowMaximise(wnd: *InternalWindow, maximised: bool) void {
    if (wnd.callbacks.maximise) |f| {
        f(@ptrCast(wnd), maximised);
    }
}

pub fn inputWindowDamage(wnd: *InternalWindow) void {
    if (wnd.callbacks.refresh) |f| {
        f(@ptrCast(wnd));
    }
}

pub fn inputWindowCloseRequest(wnd: *InternalWindow) void {
    wnd.should_close = true;

    if (wnd.callbacks.close) |f| {
        f(@ptrCast(wnd));
    }
}

pub fn inputWindowMonitor(wnd: *InternalWindow, mn: *InternalMonitor) void {
    wnd.monitor = mn;
}

pub fn inputKey(
    wnd: *InternalWindow,
    scancode: i32,
    key: definitions.Key,
    state: definitions.ElementState,
    mods: definitions.Modifiers,
) void {
    var repeated = false;
    if (state == .release and wnd.keys[@intFromEnum(key)] == .release) {
        return;
    }
    if (state == .press and wnd.keys[@intFromEnum(key)] == .press) {
        repeated = true;
    }
    wnd.keys[@intFromEnum(key)] = if (state == .release and wnd.sticky_keys)
        .stick
    else
        state;
    if (repeated) {
        state = .repeat;
    }

    if (!wnd.lock_key_mods) {
        mods.caps_lock = false;
        mods.num_lock = false;
    }

    if (wnd.callbacks.key) |f| {
        f(@ptrCast(wnd), key, scancode, state, mods);
    }
}

pub fn inputChar(
    wnd: *InternalWindow,
    codepoint: u21,
    mods: definitions.Modifiers,
    plain: bool,
) void {
    if (codepoint < 32 or (codepoint > 126 and codepoint < 160)) return;

    if (!wnd.lock_key_mods) {
        mods.caps_lock = false;
        mods.num_lock = false;
    }

    if (wnd.callbacks.char_mods) |f| {
        f(@ptrCast(wnd), codepoint, mods);
    }

    if (plain) {
        if (wnd.callbacks.char) |f| {
            f(@ptrCast(wnd), codepoint);
        }
    }
}

pub fn inputScroll(wnd: *InternalWindow, x: f64, y: f64) void {
    if (wnd.callbacks.scroll) |f| {
        f(@ptrCast(wnd), x, y);
    }
}

pub fn inputMouseClick(
    wnd: *InternalWindow,
    button: definitions.MouseButton,
    state: definitions.ElementState,
    mods: definitions.Modifiers,
) void {
    if (!wnd.lock_key_mods) {
        mods.caps_lock = false;
        mods.num_lock = false;
    }

    wnd.mouse_buttons[@intFromEnum(button)] =
        if (state == .release and wnd.sticky_mouse_buttons)
        .stick
    else
        state;

    if (wnd.callbacks.mouse_button) |f| {
        f(@ptrCast(wnd), button, state, mods);
    }
}

pub fn inputCursorPos(wnd: *InternalWindow, x: f64, y: f64) void {
    if (wnd.virtual_cursor_pos_x == x and wnd.virtual_cursor_pos_y == y) {
        return;
    }

    wnd.virtual_cursor_pos_x = x;
    wnd.virtual_cursor_pos_y = y;

    if (wnd.callbacks.cursor_pos) |f| {
        f(@ptrCast(wnd), x, y);
    }
}

pub fn inputCursorEnter(wnd: *InternalWindow, entered: bool) void {
    if (wnd.callbacks.cursor_enter) |f| {
        f(@ptrCast(wnd), entered);
    }
}

pub fn inputDrop(wnd: *InternalWindow, paths: [][]const u8) void {
    if (wnd.callbacks.drop) |f| {
        f(@ptrCast(wnd), paths);
    }
}

pub fn inputJoystickConnection(joy: *InternalJoystick, connected: bool) void {
    if (lib.callbacks.joystick) |f| {
        var start: *InternalJoystick = &lib.joysticks[0];
        f(@ptrCast(joy - start), connected);
    }
}

pub fn inputJoystickAxis(joy: *InternalJoystick, axis: i32, value: f32) void {
    joy.axes[axis] = value;
}

pub fn inputJoystickButton(
    joy: *InternalJoystick,
    button: i32,
    state: definitions.ElementState,
) void {
    joy.buttons[button] = state;
}

pub fn inputJoystickHat(joy: *InternalJoystick, hat: i32, value: u8) void {
    const base = joy.buttons.len + hat * 4;
    joy.buttons[base + 0] = if ((value & 0x01) != 0) .press else .release;
    joy.buttons[base + 1] = if ((value & 0x02) != 0) .press else .release;
    joy.buttons[base + 2] = if ((value & 0x04) != 0) .press else .release;
    joy.buttons[base + 3] = if ((value & 0x08) != 0) .press else .release;

    joy.hats[hat] = value;
}

const default_mappings = @import("../default_mappings.zig");
pub fn initGamepadMappings() void {
    const count = default_mappings.mappings.len;
    lib.mappings.ensureUnusedCapacity(lib.allocator, count);

    var index: usize = 0;
    for (default_mappings.mappings) |m| {
        if (parseMapping(&lib.mappings[index], m)) {
            index += 1;
        }
    }
}

pub fn allocateJoystick(name: []const u8, guid: [32]u8, axis_count: i32, button_count: i32, hat_count: i32) !*InternalJoystick {
    var find_joy: ?*InternalJoystick = null;
    for (lib.joysticks) |*j| {
        if (!j.allocated) {
            find_joy = j;
            break;
        }
    }

    if (find_joy == null) {
        return error.TooManyJoysticks;
    }

    var joy = find_joy.?;
    joy.allocated = true;
    joy.axes = try lib.allocator.alloc(f32, axis_count);
    joy.buttons = try lib.allocator.alloc(definitions.ElementState, button_count + hat_count * 4);
    joy.hats = try lib.allocator.alloc(u8, hat_count);

    const min_name_length: usize = @min(name.len, joy.name.len);
    @memcpy(
        joy.name[0..min_name_length],
        name[0..min_name_length],
    );

    joy.guid = guid;
    joy.mapping = findValidMapping(joy);

    return joy;
}

pub fn freeJoystick(joy: *InternalJoystick) void {
    lib.allocator.free(joy.axes);
    lib.allocator.free(joy.buttons);
    lib.allocator.free(joy.hats);
    joy.allocated = false;
}

pub fn centreCursorInContentArea(wnd: *InternalWindow) void {
    const res = lib.platform.getWindowSize(wnd);
    const float_width: f32 = @floatFromInt(res.width);
    const float_height: f32 = @floatFromInt(res.height);
    lib.platform.setCursorPos(
        wnd,
        @floatFromInt(float_width / 2.0),
        @floatFromInt(float_height / 2.0),
    );
}

pub const WindowMouseButtonCallback = *fn (
    wnd: *window.Window,
    button: definitions.MouseButton,
    action: definitions.ElementState,
    mods: definitions.Modifier,
) void;
pub const WindowCursorPosCallback = *fn (wnd: *window.Window, x: f64, y: f64) void;
pub const WindowCursorEnterCallback = *fn (wnd: *window.Window, entered: bool) void;
pub const WindowScrollCallback = *fn (wnd: *window.Window, x: f64, y: f64) void;
pub const WindowKeyCallback = *fn (
    wnd: *window.Window,
    key: definitions.Key,
    scancode: i32,
    action: definitions.ElementState,
    mods: definitions.Modifiers,
) void;
pub const WindowCharCallback = *fn (wnd: *window.Window, ch: u21) void;
pub const WindowCharModsCallback = *fn (wnd: *window.Window, ch: u21, mods: definitions.Modifier) void;
pub const WindowDropCallback = *fn (wnd: *window.Window, paths: []const []const u8) void;

pub fn getInputMode(
    wnd: *const window.Window,
    mode: definitions.InputMode,
) definitions.InputModePayload {
    const internal_window: *InternalWindow = @ptrCast(wnd);

    return switch (mode) {
        .cursor => .{ .cursor = internal_window.cursor_mode },
        .sticky_keys => .{ .sticky_keys = internal_window.sticky_keys },
        .sticky_mouse_buttons => .{ .sticky_mouse_buttons = internal_window.sticky_mouse_buttons },
        .lock_key_mods => .{ .lock_key_mods = internal_window.lock_key_mods },
        .raw_mouse_motion => .{ .raw_mouse_motion = internal_window.raw_mouse_motion },
    };
}

pub fn setInputMode(
    wnd: *window.Window,
    value: definitions.InputModePayload,
) definitions.Error!void {
    const internal_window: *InternalWindow = @ptrCast(wnd);

    switch (value) {
        .cursor => |mode| {
            if (internal_window.cursor_mode == mode)
                return;

            internal_window.cursor_mode = mode;

            const result = lib.platform.getCursorPos(internal_window);
            internal_window.virtual_cursor_pos_x = result.x;
            internal_window.virtual_cursor_pos_y = result.y;

            lib.platform.setCursorMode(internal_window, mode);
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

            lib.platform.setRawMouseMotion(internal_window, new);
        },
    }
}

pub fn isRawMouseMotionSupported() bool {
    return lib.platform.isRawMouseMotionSupported();
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

        scancode = lib.platform.getKeyScancode(key);
    }

    return lib.platform.getScancodeName(scancode);
}

pub fn getKeyScancode(key: definitions.Key) ?i32 {
    if (key == .unknown) {
        return null;
    }
    return lib.platform.getKeyScancode(key);
}

pub fn getKey(
    wnd: *const window.Window,
    key: definitions.Key,
) definitions.ElementState {
    const internal_window: *InternalWindow = @ptrCast(wnd);
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
    wnd: *const window.Window,
    button: definitions.MouseButton,
) definitions.ElementState {
    const internal_window: *InternalWindow = @ptrCast(wnd);

    if (internal_window.mouse_buttons[@intFromEnum(button)] == .stick) {
        internal_window.mouse_buttons[@intFromEnum(button)] = .release;
        return .press;
    }

    return internal_window.mouse_buttons[@intFromEnum(button)];
}

pub fn getCursorPos(wnd: *const window.Window) struct { x: f64, y: f64 } {
    const internal_window: *InternalWindow = @ptrCast(wnd);

    if (internal_window.cursor_mode == .disabled) {
        return .{ .x = internal_window.virtual_cursor_pos_x, .y = internal_window.virtual_cursor_pos_y };
    }

    return lib.platform.getCursorPos(internal_window);
}

pub fn setCursorPos(wnd: *window.Window, x: f64, y: f64) void {
    const internal_window: *InternalWindow = @ptrCast(wnd);

    if (!lib.platform.isWindowFocused(wnd)) {
        return;
    }

    if (internal_window.cursor_mode == .disabled) {
        internal_window.virtual_cursor_pos_x = x;
        internal_window.virtual_cursor_pos_y = y;
        return;
    }

    lib.platform.setCursorPos(internal_window, x, y);
}

pub fn setCursor(wnd: *window.Window, cursor: *Cursor) void {
    const internal_window: *InternalWindow = @ptrCast(wnd);
    const internal_cursor: *InternalCursor = @ptrCast(cursor);

    internal_window.cursor = internal_cursor;
    lib.platform.setCursor(internal_window, internal_cursor);
}

pub fn setKeyCallback(handle: *window.Window, cb: ?WindowKeyCallback) ?WindowKeyCallback {
    const internal_window: *InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowKeyCallback, &internal_window.callbacks.key, &cb);
    return cb;
}

pub fn setCharCallback(handle: *window.Window, cb: ?WindowCharCallback) ?WindowCharCallback {
    const internal_window: *InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowCharCallback, &internal_window.callbacks.char, &cb);
    return cb;
}

pub fn setCharModsCallback(handle: *window.Window, cb: ?WindowCharModsCallback) definitions.Error!?WindowCharModsCallback {
    const internal_window: *InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowCharModsCallback, &internal_window.callbacks.char_mods, &cb);
    return cb;
}

pub fn setMouseButtonCallback(
    handle: *window.Window,
    cb: ?WindowMouseButtonCallback,
) ?WindowMouseButtonCallback {
    const internal_window: *InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowMouseButtonCallback, &internal_window.callbacks.mouse_button, &cb);
    return cb;
}

pub fn setCursorPosCallback(
    handle: *window.Window,
    cb: ?WindowCursorPosCallback,
) ?WindowCursorPosCallback {
    const internal_window: *InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowCursorPosCallback, &internal_window.callbacks.cursor_pos, &cb);
    return cb;
}

pub fn setCursorEnterCallback(
    handle: *window.Window,
    cb: ?WindowCursorEnterCallback,
) definitions.Error!?WindowCursorEnterCallback {
    const internal_window: *InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowCursorEnterCallback, &internal_window.callbacks.cursor_enter, &cb);
    return cb;
}

pub fn setScrollCallback(
    handle: *window.Window,
    cb: ?WindowScrollCallback,
) definitions.Error!?WindowScrollCallback {
    const internal_window: *InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowScrollCallback, &internal_window.callbacks.scroll, &cb);
    return cb;
}

pub fn setDropCallback(
    handle: *window.Window,
    cb: ?WindowDropCallback,
) definitions.Error!?WindowDropCallback {
    const internal_window: *InternalWindow = @ptrCast(handle);
    std.mem.swap(?WindowDropCallback, &internal_window.callbacks.drop, &cb);
    return cb;
}

pub fn setClipboardString(wnd: *window.Window, s: []const u8) void {
    _ = wnd;
    lib.platform.setClipboardString(s);
}

pub fn getClipboardString(
    wnd: *const window.Window,
) ?[]const u8 {
    _ = wnd;
    return lib.platform.getClipboardString();
}

pub fn getTime() f64 {
    const numer: f64 = @floatFromInt((getTimerValue() - lib.timer.offset));
    const denom: f64 = @floatFromInt(getTimerFrequency());
    return numer / denom;
}

pub fn setTime(time: f64) void {
    const ffreq: f64 = @floatFromInt(getTimerFrequency());
    const other: u64 = @intCast(time * ffreq);
    lib.timer.offset = getTimerValue() - other;
}

pub fn initJoysticks() bool {
    if (!lib.joysticks_initialised) {
        if (!lib.platform.initJoysticks()) {
            lib.platform.deinitJoysticks();
            return false;
        }
    }
    lib.joysticks_initialised = true;
    return true;
}

pub fn findMapping(guid: []const u8) ?*InternalMapping {
    for (lib.mappings.items) |mapping| {
        const min_length = @min(mapping.guid.len, guid.len);
        if (std.mem.eql(u8, mapping.guid[0..min_length], guid[0..min_length])) {
            return &mapping;
        }
    }
    return null;
}

pub fn isValidElementForJoystick(
    e: *const InternalMapElement,
    joy: *const InternalJoystick,
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

pub fn findValidMapping(joy: *const InternalJoystick) ?*InternalMapping {
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

pub fn parseMapping(mapping: *InternalMapping, str: []const u8) bool {
    var fields = [_]struct { name: []const u8, element: ?*InternalMapElement }{
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

        var mapping_source_opt: ?JoystickMappingSource = mapping_source: {
            break :mapping_source switch ((parser.char() orelse return false)) {
                'a' => JoystickMappingSource.axis,
                'b' => JoystickMappingSource.button,
                'h' => JoystickMappingSource.hatbit,
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

    lib.platform.updateGamepadGuid(mapping.guid);
    return true;
}

pub fn isJoystickPresent(joy: definitions.Joystick) bool {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        return lib.platform.pollJoystick(joy, .presence);
    }
}

pub fn getJoystickAxes(joy: definitions.Joystick) ?[]const f32 {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        if (!lib.platform.pollJoystick(joy, .axes)) return null;
        return internal_joy.axes[0..internal_joy.axes.len];
    }
    return null;
}

pub fn getJoystickButtons(joy: definitions.Joystick) ?[]const definitions.ElementState {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        if (!lib.platform.pollJoystick(joy, .buttons)) return null;
        return internal_joy.buttons[0..internal_joy.buttons.len];
    }
    return null;
}

pub fn getJoystickHats(joy: definitions.Joystick) ?[]const definitions.HatState {
    if (joystickFromDefinition(joy)) |internal_joy| {
        if (!internal_joy.connected) return null;
        if (!lib.platform.pollJoystick(joy, .buttons)) return null;
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
        if (!lib.platform.pollJoystick(internal_joy, .presence)) return null;
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
    cb: ?joystick.JoystickConnectionCallback,
) ?joystick.JoystickConnectionCallback {
    if (!initJoysticks()) return null;

    std.mem.swap(?joystick.JoystickConnectionCallback, &lib.callbacks.joystick, &cb);
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
        var mapping = InternalMapping{};
        if (!parseMapping(&mapping, parser.until('\n'))) {
            return false;
        }
        if (findMapping(mapping.guid)) |previous_mapping| {
            previous_mapping.* = mapping;
        } else try lib.mappings.append(lib.allocator, mapping);
    }

    for (lib.joysticks) |joy| {
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
        if (!lib.platform.pollJoystick(joy, .all)) return null;
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

fn joystickFromDefinition(joy: definitions.Joystick) ?*InternalJoystick {
    if (!initJoysticks()) return null;

    var internal_joy = &lib.joysticks[@intFromEnum(joy)];
    if (!internal_joy.connected) return null;

    return internal_joy;
}

// monitor
pub fn refreshVideoModes(mon: *InternalMonitor) bool {
    var find_modes = lib.platform.getVideoModes(mon);
    if (find_modes == null) {
        return false;
    }
    var modes = find_modes.?;

    std.sort.pdq(definitions.VideoMode, modes, {}, definitions.VideoMode.less);

    mon.modes.deinit(lib.allocator);
    mon.modes.fromOwnedSlice(modes);

    return true;
}

pub fn inputMonitorConnection(mon: *InternalMonitor, connected: bool, place_first: bool) void {
    if (connected) {
        if (place_first) {
            lib.monitors.insert(lib.allocator, 0, mon);
        } else {
            lib.monitors.append(lib.allocator, mon);
        }
    } else {
        var window_head = lib.window_head;
        const monitor_as_public: *monitor.Monitor = @ptrCast(mon);
        while (window_head) |found_window| {
            if (found_window.monitor == monitor_as_public) {
                const wh = lib.platform.getWindowSize(found_window);
                lib.platform.setWindowMonitor(found_window, null, 0, 0, wh.width, wh.height, 0);
                const fs = lib.platform.getWindowFrameSize(found_window);
                lib.platform.setWindowPos(found_window, fs.left, fs.top);
            }
            window_head = found_window.next_window;
        }

        var monitor_index: ?usize = null;
        for (lib.monitors, 0..) |found_monitor, index| {
            if (found_monitor == mon) {
                monitor_index = index;
                break;
            }
        }

        if (monitor_index) |index| {
            lib.monitors.orderedRemove(lib.allocator, index);
        }

        if (lib.callbacks.monitor) |f| {
            f(mon, connected);
        }

        if (!connected) {
            freeMonitor(mon);
        }
    }
}

fn inputMonitorWindow(mon: *InternalMonitor, wnd: *InternalWindow) void {
    mon.current_window = wnd;
}

fn allocateMonitor(name: []const u8, width_mm: i32, height_mm: i32) !*InternalMonitor {
    const mon: *InternalMonitor = try lib.allocator.create(InternalMonitor);
    mon.width_mm = width_mm;
    mon.height_mm = height_mm;

    const min_name_length = @min(name.len, mon.name.len);
    @memcpy(mon.name[0..min_name_length], name[0..min_name_length]);

    return mon;
}

fn freeMonitor(mon: *InternalMonitor) void {
    lib.platform.freeMonitor(mon);

    if (mon.original_ramp) |*ramp| {
        freeGammaRamp(ramp);
    }
    if (mon.current_ramp) |ramp| {
        freeGammaRamp(ramp);
    }

    mon.modes.deinit(lib.allocator);
    lib.allocator.destroy(mon);
}

fn allocateGammaRamp(size: i32) !definitions.GammaRamp {
    const ramp = definitions.GammaRamp{};
    ramp.size = size;
    ramp.red = try lib.allocator.alloc(u16, size);
    ramp.green = try lib.allocator.alloc(u16, size);
    ramp.blue = try lib.allocator.alloc(u16, size);
    return ramp;
}

fn freeGammaRamp(ramp: *definitions.GammaRamp) void {
    lib.allocator.free(ramp.red);
    lib.allocator.free(ramp.green);
    lib.allocator.free(ramp.blue);
}

fn chooseVideoMode(
    mon: *InternalMonitor,
    desired: *const definitions.VideoMode,
) *const definitions.VideoMode {
    _ = desired;
    _ = mon;
}
