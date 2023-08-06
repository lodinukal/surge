const std = @import("std");

const win32 = @import("win32");
const common = @import("../../../core/common.zig");

const windows = @import("windows.zig");

const platform = @import("../platform_impl.zig");
const icon = @import("../../icon.zig");
const dpi = @import("../../dpi.zig");
const keyboard = @import("../../keyboard.zig");
const theme = @import("../../theme.zig");

const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const wam = win32.ui.windows_and_messaging;
const z32 = win32.zig;

fn bgra_pixel(pixel: *icon.Pixel) void {
    std.mem.swap(u8, &pixel.r, &pixel.b);
}

pub const IconType = enum(isize) {
    small = wam.ICON_SMALL,
    big = wam.ICON_BIG,
};

pub const WinIcon = struct {
    handle: wam.HICON,

    pub fn deinit(wi: *WinIcon) void {
        wam.DestroyIcon(wi.handle);
    }

    fn fromRgbaIcon(rgba_icon: icon.RgbaIcon, allocator: std.mem.Allocator) !WinIcon {
        const pixels = rgba_icon.pixels;
        const pixel_count = @divExact(pixels.len, icon.pixel_size);
        var and_mask = try std.ArrayList(u8).initCapacity(allocator, pixel_count);
        defer and_mask.deinit();
        for (pixels) |*pixel| {
            try and_mask.append(pixel.a -% std.math.maxInt(u8));
            bgra_pixel(&pixel);
        }
        common.assert(
            and_mask.items.len == pixel_count,
            "and_mask length does not match pixel_count: {} vs {}",
            .{ and_mask.items.len, pixel_count },
        );
        const handle = try wam.CreateIcon(
            null,
            @intCast(rgba_icon.width),
            @intCast(rgba_icon.height),
            1,
            @intCast(icon.pixel_size * 8),
            and_mask.items.ptr,
            pixels.ptr,
        );
        if (handle != 0) {
            return WinIcon{ .handle = handle };
        } else {
            return error.OsError;
        }
    }

    pub fn fromPath(path: []const u8, size: ?dpi.PhysicalSize, allocator: std.mem.Allocator) !WinIcon {
        const width = if (size) |s| s.width else 0;
        const height = if (size) |s| s.height else 0;

        const wide_path = try std.unicode.utf8ToUtf16LeWithNull(allocator, path);
        defer allocator.free(wide_path);

        const handle = wam.LoadImageW(
            null,
            wide_path.ptr,
            wam.IMAGE_ICON,
            width,
            height,
            wam.LR_LOADFROMFILE | wam.LR_DEFAULTSIZE,
        );
        if (handle != null) {
            return WinIcon{ .handle = handle };
        } else {
            return error.OsError;
        }
    }

    pub fn fromDefaultResource(resource_id: u16) !WinIcon {
        const handle = wam.LoadIconW(
            null,
            windows.makeIntResource(resource_id),
        );
        if (handle) |h| {
            return WinIcon{ .handle = @ptrCast(h) };
        } else {
            return error.OsError;
        }
    }

    pub fn fromResource(resource_id: u16, size: ?dpi.PhysicalSize) !WinIcon {
        const width = if (size) |s| s.width else 0;
        const height = if (size) |s| s.height else 0;

        const handle = wam.LoadImageW(
            windows.getInstanceHandle(),
            windows.makeIntResource(resource_id),
            wam.IMAGE_ICON,
            @intCast(width),
            @intCast(height),
            wam.LR_DEFAULTSIZE,
        );
        if (handle) |h| {
            return WinIcon{ .handle = @ptrCast(h) };
        } else {
            return error.OsError;
        }
    }

    pub fn fromRgba(rgba: []const u8, width: u32, height: u32, allocator: std.mem.Allocator) !WinIcon {
        const rgba_icon = try icon.RgbaIcon.fromRgba(rgba, width, height);
        return try WinIcon.fromRgbaIcon(rgba_icon, allocator);
    }

    pub fn setHwnd(wi: *WinIcon, hwnd: wam.HWND, icon_type: IconType) void {
        wam.SendMessageW(
            hwnd,
            wam.WM_SETICON,
            @intCast(icon_type),
            @intCast(wi.handle),
        );
    }
};
