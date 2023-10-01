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

    const X = struct {
        const Self = @This();
        pub const Virtual = struct {
            balls: ?*const fn (*Self, i32) void = null,
        };
        virtual: ?*const Virtual = null,

        pub fn balls(this: *Self, rahhh: i32) void {
            if (this.virtual) |v| if (v.*.balls) |f| {
                return f(this, rahhh);
            };
            std.debug.print("hi from X\n", .{});
        }
    };

    const Y = struct {
        const Self = @This();
        const Root = X;
        root: X = undefined,
        data: [*:0]const u8,
        padding: i64 = 100,
        const virtual = &fillVTable(Root.Virtual, Self);

        pub fn init(data: [*:0]const u8) Self {
            return .{ .root = .{ .virtual = virtual }, .data = data };
        }

        pub fn balls(this: *Self, e: i32) void {
            std.debug.print("hi from Y {} {s}\n", .{ e, this.data });
        }
    };

    var nY = Y.init(@ptrCast("hello"));
    var nX = &nY.root;
    nY.balls(3);
    nX.balls(2);
}

test {
    _ = app;
}

pub fn fillVTable(comptime VTable: type, comptime Child: type) VTable {
    var vtable: VTable = undefined;
    for (std.meta.declarations(Child)) |decl| {
        switch (@typeInfo(@TypeOf(@field(Child, decl.name)))) {
            .Fn => |f| {
                _ = f;
                if (@hasField(VTable, decl.name))
                    @field(vtable, decl.name) =
                        @as(
                        @TypeOf(
                            @field(vtable, decl.name),
                        ),
                        @ptrCast(
                            &@field(Child, decl.name),
                        ),
                    );
            },
            else => {},
        }
    }
    return vtable;
}
