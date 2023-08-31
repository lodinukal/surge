const std = @import("std");

const windows_platform = @import("windows.zig");
const windows_display = @import("display.zig");
const windows_dpi = @import("dpi.zig");
const windows_keyboard = @import("keyboard.zig");
const windows_ime = @import("ime.zig");
const windows_raw_input = @import("raw_input.zig");
const windows_theme = @import("theme.zig");
const windows_util = @import("util.zig");
const windows_window = @import("window.zig");
const windows_window_state = @import("window_state.zig");

const win32 = @import("win32");
const channel = @import("../../../core/channel.zig");
const common = @import("../../../core/common.zig");

const pump_events = @import("../pump_events.zig");

const display = @import("../../display.zig");
const dpi = @import("../../dpi.zig");
const event = @import("../../event.zig");
const event_loop = @import("../../event_loop.zig");
const icon = @import("../../icon.zig");
const keyboard = @import("../../keyboard.zig");
const window = @import("../../window.zig");

const dwm = win32.graphics.dwm;
const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const hid = win32.devices.human_interface_device;
const input = win32.ui.input;
const kam = win32.ui.input.keyboard_and_mouse;
const pointer = input.pointer;
const wam = win32.ui.windows_and_messaging;
const z32 = win32.zig;

const GetPointerFrameInfoHistory = *fn (
    pointerId: u32,
    entriesCount: *u32,
    pointerCount: *u32,
    pointerInfo: *pointer.POINTER_INFO,
) callconv(.Win64) foundation.BOOL;

const SkipPointerFrameMessages = *fn (pointerId: u32) callconv(.Win64) foundation.BOOL;
const GetPointerDeviceRects = *fn (
    device: pointer.HANDLE,
    pointerDeviceRect: *foundation.RECT,
    displayRect: *foundation.RECT,
) callconv(.Win64) foundation.BOOL;

const GetPointerTouchInfo = *fn (
    pointerId: u32,
    touchInfo: *pointer.POINTER_TOUCH_INFO,
) callconv(.Win64) foundation.BOOL;

const GetPointerPenInfo = *fn (
    pointId: u32,
    penInfo: *pointer.POINTER_PEN_INFO,
) callconv(.Win64) foundation.BOOL;

var lazyGetPointerFrameInfoHistory = windows_platform.getDllFunction(
    GetPointerFrameInfoHistory,
    "user32.dll",
    "GetPointerFrameInfoHistory",
);
var lazySkipPointerFrameMessages = windows_platform.getDllFunction(
    SkipPointerFrameMessages,
    "user32.dll",
    "SkipPointerFrameMessages",
);
var lazyGetPointerDeviceRects = windows_platform.getDllFunction(
    GetPointerDeviceRects,
    "user32.dll",
    "GetPointerDeviceRects",
);
var lazyGetPointerTouchInfo = windows_platform.getDllFunction(
    GetPointerTouchInfo,
    "user32.dll",
    "GetPointerTouchInfo",
);
var lazyGetPointerPenInfo = windows_platform.getDllFunction(
    GetPointerPenInfo,
    "user32.dll",
    "GetPointerPenInfo",
);

pub fn WindowData(comptime T: type) type {
    return struct {
        const Self = @This();
        const EventType = event.Event(T);

        allocator: std.mem.Allocator,
        window_state: *windows_window_state.WindowState,
        window_state_mutex: std.Thread.Mutex = std.Thread.Mutex{},
        event_loop_runner: EventLoopRunnerShared(T),
        userdata_removed: bool,
        recurse_depth: u32,

        pub fn deinit(wd: *Self) void {
            wd.event_loop_runner.release();
        }

        pub fn sendEvent(wd: *Self, e: EventType) !void {
            wd.event_loop_runner.retain();
            defer wd.event_loop_runner.release();

            try wd.event_loop_runner.value.sendEvent(e);
        }

        pub fn getWindowState(wd: *Self) windows_window_state.WindowState {
            wd.window_state_mutex.lock();
            defer wd.window_state_mutex.unlock();
            return wd.window_state.*;
        }
    };
}

fn ThreadMsgTargetData(comptime T: type) type {
    return struct {
        const Self = @This();
        const EventType = event.Event(T);

        allocator: std.mem.Allocator,
        event_loop_runner: EventLoopRunnerShared(T),
        user_event_propagator: channel.Receiver(T),

        pub fn init(
            allocator: std.mem.Allocator,
            event_loop_runner: EventLoopRunnerShared(T),
            user_event_propagator: channel.Receiver(T),
        ) Self {
            event_loop_runner.retain();
            return Self{
                .allocator = allocator,
                .event_loop_runner = event_loop_runner,
                .user_event_propagator = user_event_propagator,
            };
        }

        pub fn deinit(tmtd: *Self) void {
            tmtd.event_loop_runner.release();
        }

        pub fn sendEvent(tmtd: *Self, e: EventType) !void {
            tmtd.event_loop_runner.retain();
            defer tmtd.event_loop_runner.release();

            try tmtd.event_loop_runner.value.sendEvent(e);
        }
    };
}

pub const ProcResult = union(enum) {
    def_window_proc: foundation.WPARAM,
    value: isize,
};

pub fn EventLoop(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        thread_msg_sender: channel.Sender(T),
        window_target: event_loop.EventLoopWindowTarget(T),
        msg_hook: ?*fn (*const void) bool,

        pub fn init(allocator: std.mem.Allocator, attributes: *PlatformSpecificEventLoopAttributes) !Self {
            const thread_id = win32.system.threading.GetCurrentThreadId();

            if (!attributes.any_thread and thread_id != getMainThreadId()) {
                return error.InvalidThread;
            }

            if (attributes.dpi_aware) {
                windows_dpi.becomeDpiAware();
            }

            const thread_msg_target = createEventTargetWindow(T)();
            const runner_shared = eventLoopRunnerShared(T, allocator, thread_msg_target);

            const thread_msg_sender = insertEventTargetWindowData(
                T,
                thread_msg_target,
                runner_shared,
            );
            windows_raw_input.registerAllMiceAndKeyboardForRawInput(thread_msg_target, event_loop.DeviceEvents.default);

            return Self{
                .allocator = allocator,
                .thread_msg_sender = thread_msg_sender,
                .window_target = event_loop.EventLoopWindowTarget(T){
                    .p = EventLoopWindowTarget(T).init(
                        thread_id,
                        thread_msg_target,
                        runner_shared,
                    ),
                },
                .msg_hook = attributes.msg_hook,
            };
        }

        pub fn deinit(el: *Self) void {
            el.window_target.p.deinit();
        }

        pub fn getWindowTarget(el: Self) *event_loop.EventLoopWindowTarget(T) {
            return &el.window_target;
        }

        pub const RunnerFn = *fn (event.Event(T), *const event_loop.EventLoopWindowTarget(T), *event_loop.ControlFlow) void;
        pub fn run(el: *Self, event_handler: RunnerFn) EventLoopResult {
            return el.runOnDemand(event_handler);
        }

        pub fn runOnDemand(el: *Self, event_handler: RunnerFn) EventLoopResult {
            {
                const runner = el.window_target.p.runner_shared;
                runner.retain();
                defer runner.release();

                if (runner.value.getState() != RunnerState.uninitialised) {
                    return EventLoopResult.already_running;
                }

                const event_loop_windows_ref = el.window_target.p;
                runner.value.setEventHandler(@ptrCast(&event_loop_windows_ref), struct {
                    pub fn run(ctx: ?*void, e: event.Event(T), cf: *event_loop.ControlFlow) !void {
                        const inner_ref: *const event_loop.EventLoopWindowTarget(T) = @ptrCast(ctx);
                        event_handler(e, inner_ref, cf);
                    }
                }.run);
            }

            const exit_code = blk: {
                while (true) {
                    const cf_wad: event_loop.ControlFlow = el.waitAndDispatchMessages(null);
                    switch (cf_wad) {
                        .exit_with_code => |code| break :blk code,
                        else => {},
                    }
                    const cf_dpm: event_loop.ControlFlow = el.dispatchPeekedMessaged();
                    switch (cf_dpm) {
                        .exit_with_code => |code| break :blk code,
                        else => {},
                    }
                }
            };

            const runner = el.window_target.p.runner_shared;
            runner.retain();
            defer runner.release();

            runner.value.loopDestroyed();
            runner.value.resetRunner();

            if (exit_code == 0) {
                return EventLoopResult.ok;
            } else {
                return EventLoopResult{ .exit_failure = exit_code };
            }
        }

        pub fn pumpEvents(el: *Self, timeout: ?u64, event_handler_arg: RunnerFn) pump_events.PumpStatus {
            var event_handler = event_handler_arg;
            {
                const runner = el.window_target.p.runner_shared;
                runner.retain();
                defer runner.release();

                const event_loop_windows_ref = el.window_target.p;
                const Ctx = struct {
                    ref: event_loop.EventLoopWindowTarget(T),
                    event_handler: RunnerFn,
                };
                const made_ctx = Ctx{
                    .ref = event_loop_windows_ref,
                    .event_handle = event_handler,
                };
                runner.value.setEventHandler(@ptrCast(&made_ctx), struct {
                    pub fn run(ctx: ?*void, e: event.Event(T), cf: *event_loop.ControlFlow) !void {
                        const ctx_converted: *Ctx = @ptrCast(ctx);
                        ctx_converted.event_handler(e, ctx_converted.ref, cf);
                    }
                }.run);
                runner.value.wakeup();
            }
            switch (el.waitAndDispatchMessage(timeout)) {
                .exit_with_code => |_| {
                    el.dispatchPeekedMessages();
                },
                else => {},
            }

            const runner = el.window_target.p.runner_shared;
            runner.retain();
            defer runner.release();

            const status = switch (runner.value.getControlFlow()) {
                .exit_with_code => |code| blk: {
                    runner.value.loopDestroyed();
                    runner.value.resetRunner();
                    break :blk pump_events.PumpStatus{ .exit = code };
                },
                else => blk: {
                    runner.value.prepareWait();
                    break :blk pump_events.PumpStatus{.@"continue"};
                },
            };
            runner.value.clearEventHandler();

            return status;
        }

        fn waitAndDispatchMessage(el: *Self, timeout: ?u64) event_loop.ControlFlow {
            const start = std.time.Instant.now() catch unreachable;

            const runner = el.window_target.p.runner_shared;
            runner.retain();
            defer runner.release();

            const control_flow_timeout: ?u64 = switch (runner.value.getControlFlow()) {
                .wait => null,
                .poll => 0,
                .wait_until => |wait_deadline| start.since(wait_deadline),
                else => unreachable,
            };

            const use_timeout = minTimeout(control_flow_timeout, timeout);

            const getMsgWithTimeout = struct {
                pub fn f(msg: *wam.MSG, this_timeout: ?u64) pump_events.PumpStatus {
                    const timer_id: ?usize = if (this_timeout) |t| wam.SetTimer(
                        null,
                        0,
                        durationToTimeout(t),
                        null,
                    ) else null;
                    const get_status = wam.GetMessageW(
                        msg,
                        0,
                        0,
                        0,
                    );
                    if (timer_id) |tid| {
                        wam.KillTimer(null, tid);
                    }
                    if (get_status == z32.TRUE) {
                        return pump_events.PumpStatus{.@"continue"};
                    } else {
                        return pump_events.PumpStatus{.exit};
                    }
                }
            }.f;

            const waitForMsg = struct {
                pub fn f(msg: *wam.MSG, this_timeout: ?u64) ?pump_events.PumpStatus {
                    if (this_timeout == 0) {
                        if (wam.PeekMessageW(
                            msg,
                            null,
                            0,
                            0,
                            wam.PM_REMOVE,
                        ) == z32.TRUE) {
                            return pump_events.PumpStatus{.@"continue"};
                        } else {
                            return null;
                        }
                    } else {
                        return getMsgWithTimeout(msg, this_timeout);
                    }
                }
            }.f;

            runner.value.prepareWait();

            var msg = std.mem.zeroes(wam.MSG);
            const msg_status = waitForMsg(&msg, use_timeout);

            runner.value.wakeup();

            if (msg_status) |status| {
                switch (status) {
                    .exit => |code| blk: {
                        runner.value.setExitControlFlow(code);
                        break :blk runner.value.control_flow;
                    },
                    .@"continue" => {
                        const handled = blk: {
                            if (el.msg_hook) |callback| {
                                break :blk callback(@ptrCast(&msg));
                            } else {
                                break :blk false;
                            }
                        };
                        if (!handled) {
                            wam.TranslateMessage(&msg);
                            wam.DispatchMessageW(&msg);
                        }
                    },
                }
            }

            return runner.value.getControlFlow();
        }

        fn dispatchPeekedMessages(el: *Self) event_loop.ControlFlow {
            const runner = el.window_target.p.runner_shared;
            runner.retain();
            defer runner.release();

            runner.value.interrupt_msg_dispatch = false;

            var msg = std.mem.zeroes(wam.MSG);
            var control_flow = runner.value.getControlFlow();
            while (true) {
                if (wam.PeekMessageW(
                    &msg,
                    null,
                    0,
                    0,
                    wam.PM_REMOVE,
                ) == z32.FALSE) {
                    break;
                }

                const handled = blk: {
                    if (el.msg_hook) |callback| {
                        break :blk callback(@ptrCast(&msg));
                    } else {
                        break :blk false;
                    }
                };

                if (!handled) {
                    wam.TranslateMessage(&msg);
                    wam.DispatchMessageW(&msg);
                }

                control_flow = runner.value.getControlFlow();
                switch (control_flow) {
                    .exit_with_code => |_| break,
                    else => {},
                }

                if (runner.value.interrupt_msg_dispatch) {
                    break;
                }
            }

            return control_flow;
        }

        pub fn createProxy(el: *Self) EventLoopProxy(T) {
            return EventLoopProxy(T){
                .target_window = el.window_target.p.thread_msg_target,
                .event_send = el.thread_msg_sender,
            };
        }
    };
}

pub const EventLoopErrorTag = enum { ok, not_supported, os, already_running, recreation_attempt, exit_failure };
pub const EventLoopResult = union(EventLoopErrorTag) {
    ok,
    not_supported,
    os,
    already_running,
    recreation_attempt,
    exit_failure: i32,
};

pub const PlatformSpecificEventLoopAttributes = struct {
    any_thread: bool = false,
    dpi_aware: bool = true,
    msg_hook: ?*fn (*const void) bool = null,
};

pub fn EventLoopWindowTarget(comptime T: type) type {
    return struct {
        const Self = @This();

        thread_id: u32,
        thread_msg_target: foundation.HWND,
        runner_shared: EventLoopRunnerShared(T),

        pub fn init(thread_id: u32, thread_msg_target: foundation.HWND, runner_shared: EventLoopRunnerShared(T)) Self {
            runner_shared.retain();
            return Self{
                .thread_id = thread_id,
                .thread_msg_target = thread_msg_target,
                .runner_shared = runner_shared,
            };
        }

        pub fn deinit(elt: *Self) void {
            elt.runner_shared.release();
            wam.DestroyWindow(elt.thread_msg_target);
        }

        pub inline fn createThreadExecutor(elt: *Self) EventLoopThreadExecutor {
            return EventLoopThreadExecutor{
                .thread_id = elt.thread_id,
                .target_window = elt.thread_msg_target,
            };
        }

        pub fn getAvailableDisplays(elt: Self, allocator: std.mem.Allocator) ![]windows_display.DisplayHandle {
            _ = elt;
            return windows_display.DisplayHandle.getAvailableDisplays(allocator);
        }

        pub fn getPrimaryDisplay(elt: Self) ?display.PlatformDisplayHandle {
            _ = elt;
            return display.PlatformDisplayHandle.getPrimary();
        }

        pub fn listenDeviceEvents(elt: Self, allowed: event_loop.DeviceEvents) void {
            windows_raw_input.registerAllMiceAndKeyboardForRawInput(elt.thread_msg_target, allowed);
        }
    };
}

pub const EventLoopThreadExecutor = struct {
    const Self = @This();

    thread_id: u32,
    target_window: foundation.HWND,

    pub fn isInEventLoopThread(elt: Self) bool {
        return elt.thread_id == win32.system.threading.GetCurrentThreadId();
    }

    pub fn executeInThread(elt: Self, f: *fn () void) void {
        if (elt.isInEventLoopThread()) {
            f();
        } else {
            const res = wam.PostMessageW(
                elt.target_window,
                exec_msg_id.get(),
                @intFromPtr(f),
                0,
            );
            common.assert(
                res != z32.FALSE,
                "EventLoopThreadExecutor.executeInThread: PostMessageW failed",
                .{},
            );
        }
    }
};

pub fn EventLoopProxy(comptime T: type) type {
    return struct {
        const Self = @This();

        target_window: foundation.HWND,
        event_send: channel.Sender(T),

        pub fn sendEvent(elp: *Self, e: T) !void {
            if (wam.PostMessageW(elp.target_window, user_event_msg_id.get(), 0, 0) == z32.TRUE) {
                try elp.event_send.send(e);
            }
            return error.EventLoopClosed;
        }
    };
}

const thread_event_target_window_class = std.unicode.utf8ToUtf16LeStringLiteral("engine_thread_event_target");
var user_event_msg_id = LazyMesageId.init(@ptrCast("engine_wakeup_msg"));
var exec_msg_id = LazyMesageId.init(@ptrCast("engine_exec_msg"));
var destroy_msg_id = LazyMesageId.init(@ptrCast("engine_destroy_msg"));
var set_retain_state_on_size_msg_id = LazyMesageId.init(@ptrCast("engine_set_retain_state_on_size_msg"));
var taskbar_created_msg_id = LazyMesageId.init(@ptrCast("engine_taskbar_created_msg"));

fn createEventTargetWindow(comptime T: type) fn () foundation.HWND {
    const CS_HREDRAW = wam.CS_HREDRAW;
    const CS_VREDRAW = wam.CS_VREDRAW;

    const class = wam.WNDCLASSEXW{
        .cbSize = @sizeOf(wam.WNDCLASSEXW),
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = &threadEventTargetCallback(T),
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = windows_platform.getInstanceHandle(),
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = thread_event_target_window_class,
        .hIconSm = null,
    };
    wam.RegisterClassExW(&class);

    const wnd = wam.CreateWindowExW(
        wam.WS_EX_NOACTIVATE |
            wam.WS_EX_TRANSPARENT |
            wam.WS_EX_LAYERED |
            wam.WS_EX_TOOLWINDOW,
        thread_event_target_window_class,
        null,
        wam.WS_POPUP,
        0,
        0,
        0,
        0,
        null,
        null,
        windows_platform.getInstanceHandle(),
        null,
    );
    windows_platform.setWindowLong(
        wnd,
        wam.GWL_STYLE,
        @as(isize, (wam.WS_VISIBLE | wam.WS_POPUP)),
    );
    return wnd;
}

fn insertEventTargetWindowData(
    comptime T: type,
    allocator: std.mem.Allocator,
    thread_msg_target: foundation.HWND,
    event_loop_runner: EventLoopRunnerShared(T),
) channel.Sender(T) {
    event_loop_runner.retain();
    defer event_loop_runner.release();

    const c = channel.Channel(T).init(allocator);
    const userdata = ThreadMsgTargetData(T).init(
        allocator,
        event_loop_runner,
        c.getReceiver(),
    );
    const allocated_userdata = allocator.create(ThreadMsgTargetData(T));
    allocated_userdata.* = userdata;
    windows_platform.setWindowLong(
        thread_msg_target,
        wam.GWL_USERDATA,
        @as(isize, allocated_userdata),
    );
    return c.getSender();
}

fn captureMouse(wnd: foundation.HWND, window_state: *windows_window_state.WindowState) void {
    window_state.mouse.capture_count += 1;
    win32.ui.input.keyboard_and_mouse.SetCapture(wnd);
}

fn releaseMouse(window_state: *windows_window_state.WindowState) void {
    window_state.mouse.capture_count -= 1;
    if (window_state.mouse.capture_count == 0) {
        win32.ui.input.keyboard_and_mouse.ReleaseCapture();
    }
}

fn normalisePointerPressure(pressure: u32) ?event.Force {
    switch (pressure) {
        1...1024 => event.Force{ .normalised = @as(f64, @floatFromInt(pressure)) / 1024.0 },
        else => return null,
    }
}

fn updateModifiers(comptime T: type, wnd: foundation.HWND, userdata: *const WindowData(T)) void {
    const modifiers = getModifiers();

    var window_state = userdata.window_state;
    var unlocked = false;
    userdata.window_state_mutex.lock();
    defer if (unlocked) userdata.window_state_mutex.unlock();

    if (!std.mem.eql(window_state.modifiers_state, modifiers)) {
        window_state.modifiers_state = modifiers;
        userdata.window_state_mutex.unlock();
        unlocked = true;

        userdata.sendEvent(WindowData(T).EventType{ .window_event = .{
            .window_id = window.WindowId{
                .platform_window_id = .{
                    .hwnd = wnd,
                },
            },
            .event = event.WindowEvent{ .modifiers_changed = event.Modifiers.fromModifiersState(modifiers) },
        } });
    }
}

fn getModifiers() keyboard.ModifiersState {
    var modifiers = keyboard.ModifiersState{};
    modifiers.shift = isKeyDown(kam.VK_SHIFT);
    modifiers.ctrl = isKeyDown(kam.VK_CONTROL);
    modifiers.alt = isKeyDown(kam.VK_MENU);
    modifiers.super = isKeyDown(kam.VK_LWIN) || isKeyDown(kam.VK_RWIN);
}

fn isKeyDown(k: kam.VIRTUAL_KEY) bool {
    return (kam.GetAsyncKeyState(k) & (1 << 15)) != 0;
}

fn gainActiveFocus(comptime T: type, wnd: foundation.HWND, userdata: *const WindowData(T)) void {
    updateModifiers(T, wnd, userdata);

    userdata.sendEvent(WindowData(T).EventType{ .window_event = .{
        .window_id = window.WindowId{
            .platform_window_id = .{
                .hwnd = wnd,
            },
        },
        .event = event.WindowEvent{ .focused = true },
    } });
}

fn loseActiveFocus(comptime T: type, wnd: foundation.HWND, userdata: *const WindowData(T)) void {
    {
        var window_state = userdata.window_state;
        userdata.window_state_mutex.lock();
        defer userdata.window_state_mutex.unlock();

        window_state.modifiers_state = keyboard.ModifiersState{};
    }

    userdata.sendEvent(WindowData(T).EventType{ .window_event = .{
        .window_id = window.WindowId{
            .platform_window_id = .{
                .hwnd = wnd,
            },
        },
        .event = event.WindowEvent{ .modifiers_changed = event.Modifiers.fromModifiersState(
            keyboard.ModifiersState{},
        ) },
    } });

    userdata.sendEvent(WindowData(T).EventType{ .window_event = .{
        .window_id = window.WindowId{
            .platform_window_id = .{
                .hwnd = wnd,
            },
        },
        .event = event.WindowEvent{ .focused = false },
    } });
}

fn publicWindowCallback(comptime T: type) wam.WNDPROC {
    return struct {
        pub fn callback(
            wnd: foundation.HWND,
            msg: u32,
            wparam: foundation.WPARAM,
            lparam: foundation.LPARAM,
        ) callconv(.Win64) foundation.LRESULT {
            const userdata = windows_platform.getWindowLong(wnd, wam.GWL_USERDATA);

            const userdata_ptr: *WindowData(T) = userblk: {
                if (userdata == 0 and msg == wam.WM_NCCREATE) {
                    const createstruct: *wam.CREATESTRUCTW = @ptrCast(lparam);
                    const initdata: ?*windows_window.WindowInitData(T) = @ptrCast(createstruct.lpCreateParams);

                    const result = if (initdata.?.onNcCreate(wnd)) |new_userdata| blk: {
                        windows_platform.setWindowLong(
                            wnd,
                            wam.GWL_USERDATA,
                            @ptrFromInt(new_userdata),
                        );
                        break :blk wam.DefWindowProcW(wnd, msg, wparam, lparam);
                    } else -1;
                    return result;
                }
                if (userdata == 0 and msg == wam.WM_CREATE) return -1;
                if (msg == wam.WM_CREATE) {
                    const createstruct: *wam.CREATESTRUCTW = @ptrCast(lparam);
                    const initdata: ?*windows_window.WindowInitData(T) = @ptrCast(createstruct.lpCreateParams);

                    initdata.onCreate();
                    return wam.DefWindowProcW(wnd, msg, wparam, lparam);
                }
                if (userdata == 0) {
                    return wam.DefWindowProcW(wnd, msg, wparam, lparam);
                }
                break :userblk @ptrFromInt(userdata);
            };

            userdata_ptr.recurse_depth += 1;
            const result = publicWindowCallbackInner(
                T,
                wnd,
                msg,
                wparam,
                lparam,
                userdata_ptr,
            );
            _ = result;
            const userdata_removed = userdata_ptr.userdata_removed;
            const recurse_depth = userdata_ptr.recurse_depth - 1;
            userdata_ptr.recurse_depth = recurse_depth;

            if (userdata_removed and recurse_depth == 0) {
                userdata_ptr.deinit();
                userdata_ptr.allocator.destroy(userdata_ptr);
            }
        }
    }.callback;
}

fn publicWindowCallbackInner(
    comptime T: type,
    wnd: foundation.HWND,
    msg: u32,
    wparam: foundation.WPARAM,
    lparam: foundation.LPARAM,
    userdata: *WindowData(T),
) foundation.LRESULT {
    _ = lparam;
    var result = ProcResult{ .def_window_proc = wparam };
    {
        switch (msg) {
            wam.WM_KEYDOWN, wam.WM_SYSKEYDOWN, wam.WM_KEYUP, wam.WM_SYSKEYUP => {
                updateModifiers(T, wnd, userdata);
                result = ProcResult{ .value = 0 };
            },
            else => {},
        }
    }
    {
        // TODO: Keyevents
    }
}

fn threadEventTargetCallback(comptime T: type) wam.WNDPROC {
    return struct {
        pub fn callback(
            wnd: foundation.HWND,
            msg: u32,
            wparam: foundation.WPARAM,
            lparam: foundation.LPARAM,
        ) callconv(.Win64) foundation.LRESULT {
            const userdata_ptr: ?*ThreadMsgTargetData(T) = @ptrFromInt(
                windows_platform.getWindowLong(wnd, wam.GWL_USERDATA),
            );
            if (userdata_ptr == null) {
                return wam.DefWindowProcW(wnd, msg, wparam, lparam);
            }
            const userdata = userdata_ptr.?;

            if (msg != wam.WM_PAINT) {
                gdi.RedrawWindow(wnd, null, null, gdi.RDW_INTERNALPAINT);
            }

            var userdata_removed = false;
            const result = switch (msg) {
                wam.WM_NCDESTROY => blk: {
                    windows_platform.setWindowLong(wnd, wam.GWL_USERDATA, 0);
                    userdata_removed = true;
                    break :blk 0;
                },
                wam.WM_PAINT => blk: {
                    gdi.ValidateRect(wnd, null);
                    break :blk wam.DefWindowProcW(wnd, msg, wparam, lparam);
                },
                wam.WM_INPUT_DEVICE_CHANGE => blk: {
                    const send_event = switch (wparam) {
                        wam.GIDC_ARRIVAL => event.DeviceEvent{.added},
                        wam.GIDC_REMOVAL => event.DeviceEvent{.removed},
                        else => unreachable,
                    };
                    userdata.sendEvent(WindowData(T).EventType{ .device_event = .{
                        .device_id = windows_platform.wrapDeviceId(@intCast(lparam)),
                        .event = send_event,
                    } });
                    break :blk 0;
                },
                wam.WM_INPUT => blk: {
                    if (windows_raw_input.getRawInputData(@bitCast(lparam))) |data| {
                        handleRawInput(T, userdata, data);
                    }
                    break :blk wam.DefWindowProcW(wnd, msg, wparam, lparam);
                },
                else => blk: {
                    if (msg == user_event_msg_id.get()) {
                        if (try userdata.user_event_propagator.receive()) |e| {
                            userdata.sendEvent(event.Event(T){ .user_event = e });
                        }
                        break :blk 0;
                    } else if (msg == exec_msg_id.get()) {
                        var fun: *fn () void = @ptrCast(wparam);
                        fun();
                        break :blk 0;
                    }
                    break :blk wam.DefWindowProcW(wnd, msg, wparam, lparam);
                },
            };

            if (userdata_removed) {
                userdata.deinit();
                userdata.allocator.destroy(userdata);
            }

            return result;
        }
    }.callback;
}

pub fn handleRawInput(comptime T: type, userdata: *ThreadMsgTargetData(T), data: input.RAWINPUT) void {
    const device_id = windows_platform.wrapDeviceId(@intFromPtr(data.header.hDevice.?));
    if (data.header.dwType == input.RIM_TYPEMOUSE) {
        const mouse = data.data.mouse;

        if ((@as(u32, @intCast(mouse.usFlags)) & hid.MOUSE_MOVE_RELATIVE) != 0) {
            const x: f64 = @floatFromInt(mouse.lLastX);
            const y: f64 = @floatFromInt(mouse.lLastY);

            if (x != 0.0) {
                userdata.sendEvent(WindowData(T).EventType{ .device_event = .{
                    .device_id = device_id,
                    .event = event.DeviceEvent{ .motion = .{ .axis = 0, .value = x } },
                } });
            }

            if (y != 0.0) {
                userdata.sendEvent(WindowData(T).EventType{ .device_event = .{
                    .device_id = device_id,
                    .event = event.DeviceEvent{ .motion = .{ .axis = 1, .value = y } },
                } });
            }

            if (x != 0.0 or y != 0.0) {
                userdata.sendEvent(WindowData(T).EventType{ .device_event = .{
                    .device_id = device_id,
                    .event = event.DeviceEvent{ .mouse_motion = .{ .delta = .{ x, y } } },
                } });
            }
        }

        const button_flags = mouse.Anonymous.Anonymous.usButtonFlags;

        if ((button_flags & wam.RI_MOUSE_WHEEL) != 0) {
            const button_data = mouse.Anonymous.Anonymous.usButtonData;
            const delta = @as(
                f32,
                @as(i16, button_data),
            ) / @as(
                f32,
                @floatFromInt(wam.WHEEL_DELTA),
            );
            userdata.sendEvent(WindowData(T).EventType{ .device_event = .{
                .device_id = device_id,
                .event = event.DeviceEvent{ .mouse_wheel = .{
                    .delta = event.MouseScrollDelta{ .line_delta = .{ 0.0, delta } },
                } },
            } });
        }

        const button_state = windows_raw_input.getRawMouseButtonState(@intCast(button_flags));
        for (button_state, 0..) |opt_state, index| {
            if (opt_state) |state| {
                const button: u32 = @intCast(index + 1);
                userdata.sendEvent(WindowData(T).EventType{ .device_event = .{
                    .device_id = device_id,
                    .event = event.DeviceEvent{ .button = .{ .button = button, .state = state } },
                } });
            }
        }
    } else if (data.header.dwType == input.RIM_TYPEKEYBOARD) {
        const this_keyboard = data.data.keyboard;

        const pressed = this_keyboard.Message == wam.WM_KEYDOWN or this_keyboard.Message == wam.WM_SYSKEYDOWN;
        const released = this_keyboard.Message == wam.WM_KEYUP or this_keyboard.Message == wam.WM_SYSKEYUP;

        if (!pressed or !released) {
            return;
        }
        const state = if (pressed) event.ElementState.pressed else event.ElementState.released;
        const extension = blk: {
            if (this_keyboard.Flags & wam.RI_KEY_E0) {
                break :blk 0xE000;
            } else if (this_keyboard.Flags & wam.RI_KEY_E1) {
                break :blk 0xE100;
            } else {
                break :blk 0x0000;
            }
        };
        const scancode: u16 = if (this_keyboard.MakeCode == 0)
            @intCast(kam.MapVirtualKeyW(this_keyboard.VKey, wam.MAPVK_VK_TO_VSC_EX))
        else
            (this_keyboard.MakeCode | extension);
        if (scancode == 0xE11D or scancode == 0xE02A) {
            return;
        }
        const code = if (this_keyboard.VKey == kam.VK_NUMLOCK)
            keyboard.KeyCode{.num_lock}
        else
            windows_keyboard.fromScanCode(scancode);

        if (this_keyboard.VKey == kam.VK_SHIFT) {
            switch (code) {
                .numpad_decimal,
                .numpad_0,
                .numpad_1,
                .numpad_2,
                .numpad_3,
                .numpad_4,
                .numpad_5,
                .numpad_6,
                .numpad_7,
                .numpad_8,
                .numpad_9,
                => {
                    return;
                },
                else => {},
            }
        }

        userdata.sendEvent(WindowData(T).EventType{ .device_event = .{
            .device_id = device_id,
            .event = event.DeviceEvent{ .key = .{
                .physical_key = code,
                .state = state,
            } },
        } });
    }
}

pub const LazyMesageId = struct {
    const invalid_id: u32 = 0x0;
    id: std.atomic.Atomic(u32),
    name: [:0]const u8,

    pub fn init(name: [:0]const u8) LazyMesageId {
        return LazyMesageId{
            .id = std.atomic.Atomic(u32).init(invalid_id),
            .name = name,
        };
    }

    pub fn get(lmi: *LazyMesageId) u32 {
        const id = lmi.id.load(.Unordered);
        if (id != invalid_id) {
            return id;
        }
        const new_id = wam.RegisterWindowMessageA(&lmi.name);
        common.assert(
            new_id != invalid_id,
            "LazyMessageId.get: RegisterWindowMessageA returned zero",
            .{},
        );
        lmi.id.store(new_id, .Unordered);

        return new_id;
    }
};

// Event Loop Runner

fn EventHandler(comptime T: type) type {
    return ?*fn (
        ctx: ?*void,
        event: event.Event(T),
        control_flow: *event_loop.ControlFlow,
    ) anyerror!void;
}

pub fn eventLoopRunnerShared(comptime T: type, allocator: std.mem.Allocator, value: foundation.HWND) EventLoopRunnerShared(T) {
    return common.rc(allocator, EventLoopRunner(T).init(allocator, value));
}

pub fn EventLoopRunnerShared(comptime T: type) type {
    return common.Rc(EventLoopRunner(T));
}

pub fn EventLoopRunner(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const EventHandlerType = EventHandler(T);
        pub const BufferedEventType = BufferedEvent(T);
        pub const EventType = event.Event(T);

        thread_msg_target: foundation.HWND,
        interrupt_msg_dispatch: bool,

        control_flow: event_loop.ControlFlow,
        runner_state: RunnerState,
        last_events_cleared: std.time.Instant,
        event_handler_ctx: ?*void,
        event_handler: EventHandlerType,
        event_buffer: std.ArrayList(BufferedEventType),

        pub fn init(allocator: std.mem.Allocator, thread_msg_target: foundation.HWND) Self {
            return Self{
                .thread_msg_target = thread_msg_target,
                .interrupt_msg_dispatch = false,
                .runner_state = RunnerState.uninitialised,
                .control_flow = event_loop.ControlFlow.poll,
                .last_events_cleared = std.time.Instant.now() catch null,
                .event_handler = null,
                .event_buffer = std.ArrayList(BufferedEventType).init(allocator),
            };
        }

        pub fn deinit(elr: *Self) void {
            elr.event_buffer.deinit();
        }

        pub fn setEventHandler(elr: *Self, ctx: ?*void, f: EventHandlerType) void {
            elr.event_handler_ctx = ctx;
            elr.event_handler = f;
        }

        pub fn clearEventHandler(elr: *Self) void {
            elr.event_handler_ctx = null;
            elr.event_handler = null;
        }

        pub fn resetRunner(elr: *Self) void {
            elr.interrupt_msg_dispatch = false;
            elr.runner_state = RunnerState.uninitialised;
            elr.control_flow = event_loop.ControlFlow.poll;
            elr.event_handler_ctx = null;
            elr.event_handler = null;
        }

        pub fn getThreadMsgTarget(elr: Self) foundation.HWND {
            return elr.thread_msg_target;
        }

        pub fn getState(elr: Self) RunnerState {
            return elr.runner_state;
        }

        pub fn setExitControlFlow(elr: *Self, code: i32) void {
            elr.control_flow = event_loop.ControlFlow{ .exit_with_code = code };
        }

        pub fn getControlFlow(elr: Self) event_loop.ControlFlow {
            return elr.control_flow;
        }

        pub fn shouldBuffer(elr: Self) bool {
            const handler = elr.event_handler;
            const should_buffer = handler == null;
            return should_buffer;
        }

        pub fn prepareWait(elr: *const Self) void {
            elr.moveStateTo(RunnerState.idle);
        }

        pub fn wakeup(elr: *Self) void {
            elr.moveStateTo(RunnerState.handling_main_events);
        }

        pub fn sendEvent(elr: *Self, e: EventType) std.mem.Allocator!void {
            switch (e) {
                .redraw_requested => {
                    elr.callEventHander(e);
                    elr.interrupt_msg_dispatch = true;
                    return;
                },
                else => return,
            }
            if (elr.shouldBuffer()) {
                try elr.event_buffer.append(BufferedEventType.fromEvent(e));
            } else {
                elr.callEventHandler(e);
                elr.dispatchBufferedEvents();
            }
        }

        pub fn loopDestroyed(elr: *Self) void {
            elr.moveStateTo(RunnerState.destroyed);
        }

        fn callEventHander(elr: *Self, e: EventType) void {
            var control_flow = elr.control_flow;
            var event_handler = elr.event_handler orelse return;

            _ = switch (control_flow) {
                .exit_with_code => |code| {
                    event_handler(elr.event_handler_ctx, e, &event_loop.ControlFlow{ .exit_with_code = code });
                },
                else => event_handler(elr.event_handler_ctx, e, &control_flow),
            } catch {};
        }

        fn dispatchBufferedEvents(elr: *Self) void {
            while (elr.event_buffer.popOrNull()) |be| {
                be.dispatchEvent(be, struct {
                    pub fn call(inner_be: BufferedEventType, inner_e: EventType) void {
                        inner_e.callEventHandler(inner_be);
                    }
                }.call);
            }
        }

        fn moveStateTo(elr: *Self, new_state: RunnerState) void {
            const destroyed = RunnerState.destroyed;
            const uninitialised = RunnerState.uninitialised;
            const idle = RunnerState.idle;
            const handling_main_events = RunnerState.handling_main_events;

            var old_state = elr.runner_state;
            elr.runner_state = new_state;

            if (old_state == new_state) {
                return;
            }

            if (old_state == uninitialised and new_state == handling_main_events) {
                elr.callNewEvents(true);
            }
            if (old_state == uninitialised and new_state == idle) {
                elr.callNewEvents(true);
                elr.callEventHander(EventType.about_to_wait);
                elr.last_events_cleared = std.time.Instant.now() catch null;
            }
            if (old_state == uninitialised and new_state == destroyed) {
                elr.callNewEvents(true);
                elr.callEventHander(EventType.about_to_wait);
                elr.last_events_cleared = std.time.Instant.now() catch null;
                elr.callEventHander(EventType.loop_exiting);
            }

            common.assert(new_state != uninitialised, "cannot move event_loop to uninitialised state", .{});

            if (old_state == idle and old_state == handling_main_events) {
                elr.callNewEvents(false);
            }
            if (old_state == idle and old_state == destroyed) {
                elr.callEventHander(EventType.loop_exiting);
            }

            if (old_state == handling_main_events and new_state == idle) {
                elr.callEventHander(EventType.about_to_wait);
                elr.last_events_cleared = std.time.Instant.now() catch null;
            }
            if (old_state == handling_main_events and new_state == destroyed) {
                elr.callEventHander(EventType.about_to_wait);
                elr.last_events_cleared = std.time.Instant.now() catch null;
                elr.callEventHander(EventType.loop_exiting);
            }

            common.assert(old_state != destroyed, "cannot move event_loop from destroyed state", .{});
        }

        fn callNewEvents(elr: *Self, is_init: bool) void {
            const start_cause = blk: {
                if (is_init == true) break :blk event.StartCause{.init};
                const control_flow = elr.getControlFlow();
                if (control_flow == event_loop.ControlFlow.poll) break :blk event.StartCause.poll;
                if (control_flow == event_loop.ControlFlow.exit_with_code or control_flow == event_loop.ControlFlow.wait) {
                    break :blk event.StartCause{
                        .wait_cancelled = .{
                            .requested_resume = null,
                            .start = elr.last_events_cleared,
                        },
                    };
                }
                if (control_flow == event_loop.ControlFlow.wait_until) {
                    const now = std.time.Instant.now() catch std.time.Instant{};
                    if (now.order(event_loop.ControlFlow.wait_until) == .lt) {
                        break :blk event.StartCause{
                            .wait_cancelled = .{
                                .requested_resume = event_loop.ControlFlow.wait_until,
                                .start = elr.last_events_cleared,
                            },
                        };
                    } else {
                        break :blk event.StartCause{
                            .resume_time_reached = .{
                                .requested_resume = event_loop.ControlFlow.wait_until,
                                .start = elr.last_events_cleared,
                            },
                        };
                    }
                }
            };
            elr.callEventHander(EventType{ .new_events = start_cause });
            if (is_init == true) {
                elr.callEventHander(EventType.resumed);
            }
            elr.dispatchBufferedEvents();
        }
    };
}

pub const RunnerState = enum {
    uninitialised,
    idle,
    handling_main_events,
    destroyed,
};

pub fn BufferedEvent(comptime T: type) type {
    return union(enum) {
        const Self = @This();
        const EventType = event.Event(T);

        event: EventType,
        scale_factor_changed: struct {
            id: window.WindowId,
            scale_factor: f64,
            new_inner_size: dpi.PhysicalSize,
        },

        pub fn fromEvent(e: EventType) Self {
            switch (e) {
                .window_event => |we| switch (we.event) {
                    .scale_factor_changed => |sfc| {
                        const inner_size_type = sfc.inner_size_writer.new_inner_size.?;
                        inner_size_type.mutex.lock();
                        defer inner_size_type.mutex.unlock();
                        return Self{
                            .scale_factor_changed = .{
                                .id = we.window_id,
                                .scale_factor = sfc.scale_factor,
                                .new_inner_size = inner_size_type.size,
                            },
                        };
                    },
                },
            }
            return Self{ .event = e };
        }

        pub fn dispatchEvent(be: Self, ctx: anytype, dispatch: *fn (@TypeOf(ctx), EventType) void) void {
            switch (be) {
                .event => |e| dispatch(e),
                .scale_factor_changed => |sfc| {
                    var new_inner_size = event.InnerSizeWriter.InnerSizeType{
                        .size = sfc.new_inner_size,
                    };
                    dispatch(ctx, EventType{
                        .window_event = .{
                            .window_id = sfc.id,
                            .event = event.WindowEvent{
                                .scale_factor_changed = .{
                                    .scale_factor = sfc.scale_factor,
                                    .inner_size_writer = event.InnerSizeWriter.init(&new_inner_size),
                                },
                            },
                        },
                    });
                    new_inner_size.mutex.lock();
                    defer new_inner_size.mutex.unlock();
                    const inner_size = new_inner_size.size;

                    const window_flags = blk: {
                        const userdata: *WindowData(T) = @ptrFromInt(windows_platform.getWindowLong(
                            sfc.id,
                            wam.GWL_USERDATA,
                        ));
                        break :blk userdata.getWindowState().window_flags;
                    };
                    window_flags.setSize(sfc.id.platform_window_id.hwnd, inner_size);
                },
            }
        }
    };
}

const ThreadGetterStatic = struct {
    pub var main_thread_id: u32 = 0;
};
fn mainThreadLoader() void {
    ThreadGetterStatic.main_thread_id = win32.system.threading.GetCurrentThreadId();
}
comptime {
    @export(mainThreadLoader, .{
        .section = ".CRT$XCU",
    });
}
pub fn getMainThreadId() u32 {
    return ThreadGetterStatic.main_thread_id;
}

fn minTimeout(a: ?u64, b: ?u64) ?u64 {
    if (a == null and b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return @min(a, b);
}

fn durationToTimeout(d: u64) u32 {
    return @divTrunc(d, std.time.ns_per_ms);
}
