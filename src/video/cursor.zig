const std = @import("std");
const definitions = @import("definitions.zig");
const image = @import("image.zig");
const platform = @import("./platforms/platform.zig");

pub const Cursor = struct {
    pub fn init(
        img: *const image.Image,
        xhot: i32,
        yhot: i32,
    ) std.mem.Allocator.Error!?*Cursor {
        var cursor: *platform.InternalCursor = try platform.lib.allocator.create(platform.InternalCursor);
        cursor.next_cursor = platform.lib.cursor_head;
        platform.lib.cursor_head = cursor;

        if (!platform.lib.platform.createCursor(cursor, img, xhot, yhot)) {
            Cursor.deinit(@ptrCast(cursor));
            return null;
        }

        return @ptrCast(cursor);
    }

    pub fn initStandard(
        shape: definitions.CursorShape,
    ) (std.mem.Allocator.Error | definitions.Error)!*Cursor {
        var cursor: *platform.InternalCursor = try platform.lib.allocator.create(platform.InternalCursor);
        cursor.next_cursor = platform.lib.cursor_head;
        platform.lib.cursor_head = cursor;

        if (!platform.lib.platform.createStandardCursor(cursor, shape)) {
            Cursor.deinit(@ptrCast(cursor));
            return null;
        }

        return @ptrCast(cursor);
    }

    pub fn deinit(
        c: *Cursor,
    ) definitions.Error!void {
        const internal_cursor: *platform.InternalCursor = @ptrCast(c);
        var head = platform.lib.window_head;
        while (head != null) |found_window| : (head = head.?.next_window) {
            if (found_window.cursor == internal_cursor) {
                found_window.cursor = null;
            }
        }

        platform.lib.platform.destroyCursor(internal_cursor);

        var prev_cursor: *?*platform.InternalCursor = &platform.lib.cursor_head.?;
        while (prev_cursor.* != internal_cursor) {
            prev_cursor = &prev_cursor.*.next_cursor;
        }
        prev_cursor.* = internal_cursor.next_cursor;

        platform.lib.allocator.destroy(internal_cursor);
    }
};
