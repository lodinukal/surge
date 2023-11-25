const std = @import("std");

pub fn enumFromValue(comptime E: type, value: anytype) E {
    const typeInfo = @typeInfo(@TypeOf(value));
    if (typeInfo == std.builtin.Type.EnumLiteral) {
        return @as(E, value);
    } else if (comptime std.meta.trait.isIntegral(@TypeOf(value))) {
        return @enumFromInt(value);
    } else if (@TypeOf(value) == E) {
        return value;
    } else {
        @compileError("enumFromValue: invalid type: " ++ @TypeOf(value));
    }
}

pub fn orEnum(comptime E: type, other: anytype) E {
    var result = @intFromEnum(enumFromValue(E, other.@"0"));
    inline for (other, 0..) |o, i| {
        if (i == 0) continue;
        result |= @intFromEnum(enumFromValue(E, o));
    }
    return @enumFromInt(result);
}

pub fn andEnum(comptime E: type, other: anytype) E {
    var result = @intFromEnum(enumFromValue(E, other.@"0"));
    inline for (other, 0..) |o, i| {
        if (i == 0) continue;
        result &= @intFromEnum(enumFromValue(E, o));
    }
    return @enumFromInt(result);
}

pub fn xorEnum(comptime E: type, other: anytype) E {
    var result = @intFromEnum(enumFromValue(E, other.@"0"));
    inline for (other, 0..) |o, i| {
        if (i == 0) continue;
        result ^= @intFromEnum(enumFromValue(E, o));
    }
    return @enumFromInt(result);
}

fn EnumStructInitialiser(comptime E: type) type {
    const fields = @typeInfo(E).Enum.fields;
    var new_fields: [fields.len]std.builtin.Type.StructField = undefined;
    inline for (fields, 0..) |field, i| {
        new_fields[i] = .{
            .name = field.name,
            .type = bool,
            .default_value = @ptrCast(&@as(bool, false)),
            .is_comptime = false,
            .alignment = @alignOf(bool),
        };
    }
    return @Type(.{ .Struct = .{
        .layout = .Auto,
        .fields = &new_fields,
        .decls = &.{},
        .is_tuple = false,
    } });
}

pub fn initEnum(comptime E: type, flags: EnumStructInitialiser(E)) E {
    var result: @typeInfo(E).Enum.tag_type = 0;
    const fields = @typeInfo(E).Enum.fields;
    inline for (fields) |field| {
        if (@field(flags, field.name)) {
            result |= field.value;
        }
    }
    return @enumFromInt(result);
}

test initEnum {
    const Foo = enum(u8) {
        A = 1,
        B = 2,
        C = 4,
        _,
    };
    const result = initEnum(Foo, .{
        .A = true,
        .B = false,
        .C = true,
    });
    try std.testing.expectEqual(@as(
        Foo,
        @enumFromInt(@intFromEnum(Foo.A) | @intFromEnum(Foo.C)),
    ), result);
}
