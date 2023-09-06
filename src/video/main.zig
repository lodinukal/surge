const std = @import("std");
const definitions = @import("definitions.zig");

const platform = @import("./platforms/platform.zig");

pub fn init(allocator: std.mem.Allocator) definitions.Error!bool {
    if (platform.lib.initialised) {
        return true;
    }
    platform.lib.allocator = allocator;

    platform.initGamepadMappings();
    platform.initTimer();
    platform.lib.timer.offset = platform.getTimerValue();

    platform.lib.initialised = true;

    return true;
}

pub fn deinit() void {
    if (!platform.lib.initialised) {
        return;
    }

    platform.lib.callbacks.joystick = null;
    platform.lib.callbacks.keyboard = null;

    var window_head = platform.lib.window_head;
    while (window_head) |found_window| {
        var next = found_window.next_window;
        // TODO: Window destroy
        // platform.lib.platform.(found_window);
        window_head = next;
    }

    var cursor_head = platform.lib.cursor_head;
    while (cursor_head) |found_cursor| {
        var next = found_cursor.next_cursor;
        // TODO: Cursor destroy
        // platform.lib.platform.(found_cursor);
        cursor_head = next;
    }

    for (platform.lib.monitors.items) |monitor| {
        if (monitor.original_ramp) {
            platform.lib.platform.setGammaRamp(monitor, &monitor.original_ramp.?);
        }
        // TODO: Free monitor
    }

    platform.lib.monitors.deinit(platform.lib.allocator);
    platform.lib.mappings.deinit(platform.lib.allocator);
    platform.lib.platform.deinit();

    platform.lib.initialised = false;
}

pub var current_err: ?[]const u8 = null;
pub fn getErrorString() ?[]const u8 {
    return current_err;
}
pub fn setErrorString(_err: ?[]const u8) void {
    current_err = _err;
}
