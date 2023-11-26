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
