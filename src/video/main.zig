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
pub fn setErrorString(_err: ?[]const u8) void {
    current_err = _err;
}
