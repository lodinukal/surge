const std = @import("std");

const platform = @import("./platform_impl/platform_impl.zig");

const PlatformIcon = platform.impl.Icon;

pub const CursorIcon = enum {
    default,
    context_menu,
    help,
    pointer,
    progress,
    wait,
    cell,
    crosshair,
    text,
    vertical_text,
    alias,
    copy,
    move,
    no_drop,
    not_allowed,
    grab,
    grabbing,
    e_resize,
    n_resize,
    ne_resize,
    nw_resize,
    s_resize,
    se_resize,
    sw_resize,
    w_resize,
    ew_resize,
    ns_resize,
    nesw_resize,
    nwse_resize,
    col_resize,
    row_resize,
    all_scroll,
    zoom_in,
    zoom_out,
};

pub const Pixel = struct {
    r: u32,
    g: u32,
    b: u32,
    a: u32,
};
pub const pixel_size = @sizeOf(Pixel);

pub const BadIcon = error{
    ByteNotDivisibleByFour,
    DimensionsPixelCountMismatch,
};

pub const RgbaIcon = struct {
    width: u32,
    height: u32,
    pixels: []Pixel,

    pub fn fromRgba(rgba: []const u8, width: u32, height: u32) BadIcon!RgbaIcon {
        if (rgba.len % pixel_size != 0) {
            return BadIcon.ByteNotDivisibleByFour;
        }
        const pixel_count = @divExact(rgba.len, pixel_size);
        if (pixel_count != (width * height)) {
            return BadIcon.DimensionsPixelCountMismatch;
        } else {
            return RgbaIcon{ .width = width, .height = height, .pixels = std.mem.cast([]Pixel, rgba) };
        }
    }
};

pub const NoIcon = struct {
    pub fn fromRgba(rgba: []const u8, width: u32, height: u32) BadIcon!NoIcon {
        _ = try RgbaIcon.fromRgba(rgba, width, height);
        return NoIcon{};
    }
};

pub const Icon = struct {
    inner: PlatformIcon,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Icon) void {
        self.inner.deinit();
    }

    pub fn fromRgba(rgba: []u8, width: u32, height: u32, allocator: std.mem.Allocator) !Icon {
        return Icon{
            .inner = try PlatformIcon.fromRgba(rgba, width, height, allocator),
            .allocator = allocator,
        };
    }
};
