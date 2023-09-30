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

pub fn VirtualTable(comptime T: type) type {
    var fn_count = 0;
    for (std.meta.fields(T)) |field| {
        switch (@typeInfo(field.type)) {
            .Fn => fn_count += 1,
            else => {},
        }
    }

    var fields: [fn_count]std.builtin.Type.StructField = undefined;
    var index: comptime_int = 0;
    for (std.meta.fields(T)) |field| {
        switch (@typeInfo(field.type)) {
            .Fn => |f| {
                const ptr = @Type(std.builtin.Type{ .Pointer = .{
                    .size = .One,
                    .is_const = true,
                    .is_volatile = false,
                    .alignment = 1,
                    .address_space = .generic,
                    .child = @Type(std.builtin.Type{ .Fn = f }),
                    .is_allowzero = false,
                    .sentinel = null,
                } });
                const opt = @Type(std.builtin.Type{ .Optional = .{
                    .child = ptr,
                } });
                const default_value: opt = null;
                fields[index] = .{
                    .name = field.name,
                    .type = opt,
                    .default_value = @ptrCast(&default_value),
                    .is_comptime = false,
                    .alignment = 1,
                };
                index += 1;
            },
            else => {},
        }
    }

    return @Type(std.builtin.Type{ .Struct = .{
        .layout = .Auto,
        .fields = fields[0..],
        .decls = &[_]std.builtin.Type.Declaration{},
        .is_tuple = false,
    } });
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

test "popVirtual" {
    const X = struct {
        const Self = @This();
        pub const Virtual = VirtualTable(struct {
            balls: fn (*Self, i32) void,
        });
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
        const virtual = &fillVTable(Root.Virtual, Self);

        pub fn init() Self {
            return .{ .root = .{ .virtual = virtual } };
        }

        pub fn balls(this: *Self, e: i32) void {
            _ = e;
            _ = this;
            std.debug.print("hi from Y\n", .{});
        }
    };

    var nY = Y.init();
    var nX = &nY.root;
    nY.balls(3);
    nX.balls(2);
}
