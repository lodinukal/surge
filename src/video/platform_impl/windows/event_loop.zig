const std = @import("std");

const windows_platform = @import("windows.zig");
const windows_dpi = @import("dpi.zig");
const windows_ime = @import("ime.zig");
const windows_theme = @import("theme.zig");
const windows_util = @import("util.zig");

const win32 = @import("win32");
const channel = @import("../../../core/channel.zig");
const common = @import("../../../core/common.zig");

const windows_window_state = @import("window_state.zig");

const dpi = @import("../../dpi.zig");
const event = @import("../../event.zig");
const event_loop = @import("../../event_loop.zig");
const icon = @import("../../icon.zig");
const window = @import("../../window.zig");

const dwm = win32.graphics.dwm;
const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const pointer = win32.ui.input.pointer;
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

        window_state: *windows_window_state.WindowState,
        window_state_mutex: std.Thread.Mutex = std.Thread.Mutex{},
        event_loop_runner: EventLoopRunnerShared(T),

        pub fn sendEvent(wd: *Self, e: EventType) void {
            wd.event_loop_runner.sendEvent(e);
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

        event_loop_runner: EventLoopRunnerShared(T),
        user_event_propagator: channel.Receiver(T),

        pub fn sendEvent(tmtd: *Self, e: EventType) void {
            tmtd.event_loop_runner.sendEvent(e);
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

        thread_msg_sender: channel.Sender(T),
        window_target: event_loop.EventLoopWindowTarget(T),
        msg_hook: ?*fn (*const void) bool,

        pub fn init(attributes: *PlatformSpecificEventLoopAttributes) !Self {
            const thread_id = win32.system.threading.GetCurrentThreadId();

            if (!attributes.any_thread and thread_id != getMainThreadId()) {
                return error.InvalidThread;
            }

            if (attributes.dpi_aware) {
                // becomeDpiAware();
                // TODO: finish event_loop
            }
        }
    };
}

pub const PlatformSpecificEventLoopAttributes = struct {
    any_thread: bool = false,
    dpi_aware: bool = true,
    msg_hook: ?*fn (*const void) bool = null,
};

pub fn EventLoopWindowTarget(comptime T: type) type {
    return struct {
        thread_id: u32,
        thread_msg_target: foundation.HWND,
        runner_shared: EventLoopRunnerShared(T),
    };
}

fn EventHandler(comptime T: type) type {
    return ?*fn (
        event: event.Event(T),
        control_flow: *event_loop.ControlFlow,
    ) anyerror!void;
}

pub fn EventLoopRunnerShared(comptime T: type) type {
    return *EventLoopRunner(T);
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
        event_handler: EventHandlerType,
        event_buffer: std.ArrayList(BufferedEventType),

        pub fn init(thread_msg_target: foundation.HWND, allocator: std.mem.Allocator) Self {
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

        pub fn setEventHandler(elr: *Self, f: EventHandlerType) void {
            elr.event_handler = f;
        }

        pub fn clearEventHandler(elr: *Self) void {
            elr.event_handler = null;
        }

        pub fn resetRunner(elr: *Self) void {
            elr.interrupt_msg_dispatch = false;
            elr.runner_state = RunnerState.uninitialised;
            elr.control_flow = event_loop.ControlFlow.poll;
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
                    event_handler(e, &event_loop.ControlFlow{ .exit_with_code = code });
                },
                else => event_handler(e, &control_flow),
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
