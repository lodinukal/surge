const std = @import("std");

const platform = @import("platform.zig").impl;

pub const Application = struct {
    allocator: std.mem.Allocator,

    platform_application: platform.Application = undefined,

    pub fn init(self: *Application) !void {
        try self.platform_application.init(self);
    }

    pub fn deinit(self: *Application) void {
        self.platform_application.deinit();
    }

    pub fn initWindow(self: *Application, window: *Window, descriptor: WindowDescriptor) !void {
        try self.platform_application.initWindow(window, &window.platform_window, descriptor);
    }

    pub fn pumpEvents(self: *Application) !void {
        return self.platform_application.pumpEvents();
    }
};

pub const WindowDescriptor = struct {
    title: []const u8,
    width: i32 = 800,
    height: i32 = 600,
    x: ?i32 = null,
    y: ?i32 = null,
    is_popup: bool = false,
    fullscreen_mode: FullscreenMode = FullscreenMode.windowed,
    borderless: bool = false,
    resizable: bool = true,
    open_minimised: bool = false,
};

pub const FullscreenMode = enum {
    windowed,
    borderless,
    fullscreen,
};

pub const Window = struct {
    platform_window: platform.Window = undefined,

    pub fn deinit(self: *Window) void {
        self.platform_window.deinit();
    }

    pub fn show(self: *Window, should_show: bool) void {
        self.platform_window.show(should_show);
    }

    pub fn shouldClose(self: *const Window) bool {
        return self.platform_window.shouldClose();
    }

    pub fn setShouldClose(self: *Window, should_close: bool) void {
        self.platform_window.setShouldClose(should_close);
    }
};

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
