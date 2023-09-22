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
        createFromFile: ?fn (this: *Self, path: []const u8, hotspot: math.Vector2(f32)) ?CursorHandle = null,
        isCursorFromRgbaBufferSupported: ?fn (this: *const Self) bool = null,
        createFromRgbaBuffer: ?fn (
            this: *Self,
            pixels: []const u8,
            width: i32,
            height: i32,
            hotspot: math.Vector2(f32),
        ) ?CursorHandle = null,
        getPosition: ?fn (this: *const Self) math.Vector2(f32) = null,
        setPosition: ?fn (this: *Self, x: i32, y: i32) void = null,
        getType: ?fn (this: *const Self) MouseCursor = null,
        setType: ?fn (this: *Self, cursor: MouseCursor) void = null,
        getSize: ?fn (this: *const Self) math.Vector2(f32) = null,
        show: ?fn (this: *Self, showing: bool) void = null,
        lock: ?fn (this: *Self, bounds: ?*const application.PlatformRect) void = null,
        setTypeShape: ?fn (this: *Self, cursor: MouseCursor, handle: CursorHandle) void = null,
    },

    pub fn deinit(this: *Self) void {
        if (this.virtual.deinit) |f| {
            f(this);
        }
    }

    pub fn createFromFile(this: *Self, path: []const u8, hotspot: math.Vector2(f32)) ?CursorHandle {
        if (this.virtual.createFromFile) |f| {
            return f(this, path, hotspot);
        }
        return null;
    }

    pub fn isCursorFromRgbaBufferSupported(this: *const Self) bool {
        if (this.virtual.isCursorFromRgbaBufferSupported) |f| {
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
        if (this.virtual.createFromRgbaBuffer) |f| {
            return f(this, pixels, width, height, hotspot);
        }
        return null;
    }

    pub fn getPosition(this: *const Self) math.Vector2(f32) {
        if (this.virtual.getPosition) |f| {
            return f(this);
        }
        unreachable;
    }

    pub fn setPosition(this: *Self, x: i32, y: i32) void {
        if (this.virtual.setPosition) |f| {
            f(this, x, y);
        }
    }

    pub fn getType(this: *const Self) MouseCursor {
        if (this.virtual.getType) |f| {
            return f(this);
        }
        unreachable;
    }

    pub fn setType(this: *Self, cursor: MouseCursor) void {
        if (this.virtual.setType) |f| {
            f(this, cursor);
        }
    }

    pub fn getSize(this: *const Self) math.Vector2(f32) {
        if (this.virtual.getSize) |f| {
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
        if (this.virtual.setTypeShape) |f| {
            f(this, cursor, handle);
        }
    }
};
