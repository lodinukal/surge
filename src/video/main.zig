const definitions = @import("definitions.zig");

var initialised = false;
pub fn init() definitions.Error!void {
    if (initialised) {
        return;
    }
}

pub fn deinit() void {}

pub var current_err: ?[]const u8 = null;
pub fn getErrorString() ?[]const u8 {
    return current_err;
}

pub fn getTime() f64 {
    return 0.0;
}

pub fn setTime(_time: f64) void {
    _ = _time;
}

pub fn getTimerValue() u64 {
    return 0;
}

pub fn getTimerFrequency() u64 {
    return 0;
}
