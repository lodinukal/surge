const std = @import("std");

pub fn getRoot(comptime T: type, root: anytype) if (std.meta.trait.isConstPtr(@TypeOf(root)))
    *const T
else
    *T {
    return @constCast(@fieldParentPtr(T, "root", @constCast(root)));
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

pub fn populateVirtual(comptime VTable: type, comptime Child: type) VTable {
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
