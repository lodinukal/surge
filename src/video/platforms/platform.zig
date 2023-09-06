const std = @import("std");
const definitions = @import("../definitions.zig");

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
    current_window: *InternalWindow,
    modes: []definitions.VideoMode,
    current_mode: definitions.VideoMode,
    original_ramp: definitions.GammaRamp,
    current_ramp: definitions.GammaRamp,
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
    allocated: bool,
    connected: bool,
    axes: []f32,
    buttons: []definitions.ElementState,
    hats: []u8,
    name: [128]u8,
    user_pointer: ?*void,
    guid: [33]u8,
    mapping: ?*InternalMapping = null,

    platform: impl.PlatformJoystick,
};

pub const InternalTls = struct {
    platform: impl.PlatformTls,

    pub fn init() definitions.Error!void {
        var created_tls = InternalTls{
            .platform = impl.PlatformTls{},
        };
        try created_tls.platform.init();
        return created_tls;
    }

    pub fn deinit(tls: *InternalTls) void {
        return tls.platform.deinit();
    }

    pub fn getTls(tls: *const InternalTls) *void {
        return tls.platform.getTls();
    }

    pub fn setTls(tls: *const InternalTls, value: *void) void {
        return tls.platform.setTls(value);
    }
};

pub const InternalMutex = struct {
    platform: impl.PlatformMutex,

    pub fn init() definitions.Error!InternalMutex {
        var mutex = InternalMutex{
            .platform = impl.PlatformMutex{},
        };
        try mutex.platform.init();
        return mutex;
    }

    pub fn deinit(mutex: *InternalMutex) void {
        return mutex.platform.deinit();
    }

    pub fn lock(mutex: *InternalMutex) void {
        return mutex.platform.lock();
    }

    pub fn unlock(mutex: *InternalMutex) void {
        return mutex.platform.unlock();
    }
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
    getVideoModes: fn (monitor: *InternalMonitor) []definitions.VideoMode,
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
    monitors: []*InternalMonitor,
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
