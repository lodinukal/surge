const std = @import("std");

const math = @import("../../core/math.zig");

const application = @import("application.zig");

pub const MouseCursor = enum(i32) {
    none,
    default,
    text_edit_beam,
    resize_horizontal,
    resize_vertical,
    resize_top_left_bottom_right,
    resize_top_right_bottom_left,
    cardinal_cross,
    crosshair,
    hand,
    grab_hand,
    grab_hand_closed,
    slashed_circle,
    eye_dropper,
    custom,
};

pub const Cursor = struct {
    const Self = @This();
    const CursorHandle = *anyopaque;
    virtual: struct {
        deinit: ?fn (this: *Self) void = null,
        create_from_file: ?fn (this: *Self, path: []const u8, hotspot: math.Vector2(f32)) ?CursorHandle = null,
        is_cursor_from_rgba_buffer_supported: ?fn (this: *const Self) bool = null,
        create_from_rgba_buffer: ?fn (
            this: *Self,
            pixels: []const u8,
            width: i32,
            height: i32,
            hotspot: math.Vector2(f32),
        ) ?CursorHandle = null,
        get_position: ?fn (this: *const Self) math.Vector2(f32) = null,
        set_position: ?fn (this: *Self, x: i32, y: i32) void = null,
        get_type: ?fn (this: *const Self) MouseCursor = null,
        set_type: ?fn (this: *Self, cursor: MouseCursor) void = null,
        get_size: ?fn (this: *const Self) math.Vector2(f32) = null,
        show: ?fn (this: *Self, showing: bool) void = null,
        lock: ?fn (this: *Self, bounds: ?*const application.PlatformRect) void = null,
        set_type_shape: ?fn (this: *Self, cursor: MouseCursor, handle: CursorHandle) void = null,
    },

    pub fn deinit(this: *Self) void {
        if (this.virtual.deinit) |f| {
            f(this);
        }
    }

    pub fn createFromFile(this: *Self, path: []const u8, hotspot: math.Vector2(f32)) ?CursorHandle {
        if (this.virtual.create_from_file) |f| {
            return f(this, path, hotspot);
        }
        return null;
    }

    pub fn isCursorFromRgbaBufferSupported(this: *const Self) bool {
        if (this.virtual.is_cursor_from_rgba_buffer_supported) |f| {
            return f(this);
        }
        return false;
    }

    pub fn createFromRgbaBuffer(
        this: *Self,
        pixels: []const u8,
        width: i32,
        height: i32,
        hotspot: math.Vector2(f32),
    ) ?CursorHandle {
        if (this.virtual.create_from_rgba_buffer) |f| {
            return f(this, pixels, width, height, hotspot);
        }
        return null;
    }

    pub fn getPosition(this: *const Self) math.Vector2(f32) {
        if (this.virtual.get_position) |f| {
            return f(this);
        }
        unreachable;
    }

    pub fn setPosition(this: *Self, x: i32, y: i32) void {
        if (this.virtual.set_position) |f| {
            f(this, x, y);
        }
    }

    pub fn getType(this: *const Self) MouseCursor {
        if (this.virtual.get_type) |f| {
            return f(this);
        }
        unreachable;
    }

    pub fn setType(this: *Self, cursor: MouseCursor) void {
        if (this.virtual.set_type) |f| {
            f(this, cursor);
        }
    }

    pub fn getSize(this: *const Self) math.Vector2(f32) {
        if (this.virtual.get_size) |f| {
            return f(this);
        }
        unreachable;
    }

    pub fn show(this: *Self, showing: bool) void {
        if (this.virtual.show) |f| {
            f(this, showing);
        }
    }

    pub fn lock(this: *Self, bounds: ?*const application.PlatformRect) void {
        if (this.virtual.lock) |f| {
            f(this, bounds);
        }
    }

    pub fn setTypeShape(this: *Self, cursor: MouseCursor, handle: CursorHandle) void {
        if (this.virtual.set_type_shape) |f| {
            f(this, cursor, handle);
        }
    }
};
