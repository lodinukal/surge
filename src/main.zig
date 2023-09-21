const std = @import("std");

const app = @import("app/generic/input_device_mapper.zig");
const pam = @import("app/windows/platform_application_misc.zig");
const math = @import("core/math.zig");

const interface = @import("core/interface.zig");

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

test "popVirtual" {
    const X = struct {
        const Self = @This();
        virtual: struct {
            balls: ?*fn (this: *Self) void = null,
        } = undefined,

        pub fn balls(this: *Self) void {
            if (this.virtual.balls) |f| {
                return f(this);
            }
            std.debug.print("hi from X\n", .{});
        }
    };

    const Y = struct {
        const Self = @This();
        root: X = undefined,
        virtual: struct {
            balls: ?*fn (this: *Self) void = null,
        } = undefined,

        pub fn balls(this: *Self) void {
            _ = this;
            std.debug.print("hi from Y\n", .{});
        }
    };

    var nY = Y{};
    nY.root = X{};
    interface.populateVirtual(&nY.root, Y);

    var nX = X{};

    nY.root.balls();
    nX.balls();
}
