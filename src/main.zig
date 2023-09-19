const std = @import("std");

const app = @import("app/generic/input_device_mapper.zig");
const pam = @import("app/windows/platform_application_misc.zig");
const math = @import("core/math.zig");

pub const X = enum(i32) {
    a,
    b,
    c,
    d,
};

pub fn egg() !bool {
    return true;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    std.debug.print("{!s}\n", .{pam.WindowsPlatformApplicationMisc.clipboardPaste(alloc)});
    pam.WindowsPlatformApplicationMisc.clipboardCopy("hi bloxit");
}

test {
    _ = app;
}
