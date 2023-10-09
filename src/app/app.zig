const std = @import("std");

const platform = @import("platform.zig").impl;

pub const Application = struct {
    allocator: std.mem.Allocator,

    platform_application: platform.Application = undefined,

    pub fn create(allocator: std.mem.Allocator) !*Application {
        var app: *Application = try allocator.create(Application);
        app.allocator = allocator;
        try app.init();
        return app;
    }

    pub fn destroy(self: *Application) void {
        self.deinit();
        self.allocator.destroy(self);
    }

    fn init(self: *Application) !void {
        try self.platform_application.init();
    }

    fn deinit(self: *Application) void {
        self.platform_application.deinit();
    }

    pub fn createWindow(self: *Application, descriptor: WindowDescriptor) !*Window {
        var window: *Window = try self.allocator.create(Window);
        window.application = self;
        try window.platform_window.init(descriptor);
        return window;
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
    application: *Application = undefined,

    pub inline fn allocator(self: *const Window) std.mem.Allocator {
        return self.application.allocator;
    }

    pub fn destroy(self: *Window) void {
        self.deinit();
        self.allocator().destroy(self);
    }

    fn deinit(self: *Window) void {
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
