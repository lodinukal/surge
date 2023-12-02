const std = @import("std");

pub fn enumFromValue(comptime E: type, value: anytype) E {
    const typeInfo = @typeInfo(@TypeOf(value));
    if (typeInfo == std.builtin.Type.EnumLiteral) {
        return @as(E, value);
    } else if (typeInfo == .Int) {
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

pub fn ErrorEnum(comptime E: type) type {
    const ti = @typeInfo(E);
    const error_set = ti.ErrorSet.?;
    comptime var enum_fields: [error_set.len]std.builtin.Type.EnumField = undefined;
    inline for (error_set, 0..) |e, index| {
        enum_fields[index] = .{
            .name = e.name,
            .value = index,
        };
    }

    return @Type(std.builtin.Type{
        .Enum = .{
            .tag_type = u16,
            .fields = &enum_fields,
            .decls = &.{},
            .is_exhaustive = true,
        },
    });
}

pub fn errorEnumFromError(comptime E: type, err: E) ErrorEnum(E) {
    return @field(ErrorEnum(E), @errorName(err));
}

pub fn errorFromErrorEnum(comptime E: type, err: E) E {
    return @field(E, @tagName(err));
}
