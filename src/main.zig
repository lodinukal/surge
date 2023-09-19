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

    _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
    std.debug.print("{!s}\n", .{pam.WindowsPlatformApplicationMisc.clipboardPaste(alloc)});
}

test {
    _ = app;
}
