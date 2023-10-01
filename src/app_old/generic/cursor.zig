const std = @import("std");

const interface = @import("../../core/interface.zig");
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
    pub const Virtual = interface.VirtualTable(struct {
        deinit: fn (this: *Self) void,
        createFromFile: fn (this: *Self, path: []const u8, hotspot: math.Vector2(f32)) ?CursorHandle,
        isCursorFromRgbaBufferSupported: fn (this: *const Self) bool,
        createFromRgbaBuffer: fn (
            this: *Self,
            pixels: []const u8,
            width: i32,
            height: i32,
            hotspot: math.Vector2(f32),
        ) ?CursorHandle,
        getPosition: fn (this: *const Self) math.Vector2(f32),
        setPosition: fn (this: *Self, x: i32, y: i32) void,
        getType: fn (this: *const Self) MouseCursor,
        setType: fn (this: *Self, cursor: MouseCursor) void,
        getSize: fn (this: *const Self) math.Vector2(f32),
        show: fn (this: *Self, showing: bool) void,
        lock: fn (this: *Self, bounds: ?*const application.PlatformRect) void,
        setTypeShape: fn (this: *Self, cursor: MouseCursor, handle: CursorHandle) void,
    });
    virtual: ?*const Virtual = null,

    pub fn deinit(this: *Self) void {
        if (this.virtual) |v| if (v.deinit) |f| {
            f(this);
        };
    }

    pub fn createFromFile(this: *Self, path: []const u8, hotspot: math.Vector2(f32)) ?CursorHandle {
        if (this.virtual) |v| if (v.createFromFile) |f| {
            return f(this, path, hotspot);
        };
        return null;
    }

    pub fn isCursorFromRgbaBufferSupported(this: *const Self) bool {
        if (this.virtual) |v| if (v.isCursorFromRgbaBufferSupported) |f| {
            return f(this);
        };
        return false;
    }

    pub fn createFromRgbaBuffer(
        this: *Self,
        pixels: []const u8,
        width: i32,
        height: i32,
        hotspot: math.Vector2(f32),
    ) ?CursorHandle {
        if (this.virtual) |v| if (v.createFromRgbaBuffer) |f| {
            return f(this, pixels, width, height, hotspot);
        };
        return null;
    }

    pub fn getPosition(this: *const Self) math.Vector2(f32) {
        if (this.virtual) |v| if (v.getPosition) |f| {
            return f(this);
        };
        unreachable;
    }

    pub fn setPosition(this: *Self, x: i32, y: i32) void {
        if (this.virtual) |v| if (v.setPosition) |f| {
            f(this, x, y);
        };
    }

    pub fn getType(this: *const Self) MouseCursor {
        if (this.virtual) |v| if (v.getType) |f| {
            return f(this);
        };
        unreachable;
    }

    pub fn setType(this: *Self, cursor: MouseCursor) void {
        if (this.virtual) |v| if (v.setType) |f| {
            f(this, cursor);
        };
    }

    pub fn getSize(this: *const Self) math.Vector2(f32) {
        if (this.virtual) |v| if (v.getSize) |f| {
            return f(this);
        };
        unreachable;
    }

    pub fn show(this: *Self, showing: bool) void {
        if (this.virtual) |v| if (v.show) |f| {
            f(this, showing);
        };
    }

    pub fn lock(this: *Self, bounds: ?*const application.PlatformRect) void {
        if (this.virtual) |v| if (v.lock) |f| {
            f(this, bounds);
        };
    }

    pub fn setTypeShape(this: *Self, cursor: MouseCursor, handle: CursorHandle) void {
        if (this.virtual) |v| if (v.setTypeShape) |f| {
            f(this, cursor, handle);
        };
    }
};
