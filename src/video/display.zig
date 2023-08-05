const std = @import("std");

const platform = @import("./platform.zig");
const dpi = @import("dpi.zig");

pub const PlatformVideoMode = platform.impl.display.VideoMode;
pub const PlatformDisplayHandle = platform.impl.display.DisplayHandle;

pub const VideoMode = struct {
    platform_video_mode: PlatformVideoMode,

    pub fn deinit(self: *VideoMode, allocator: std.mem.Allocator) void {
        self.platform_video_mode.deinit(allocator);
    }

    pub fn getSize(self: VideoMode) dpi.PhysicalSize {
        return self.platform_video_mode.getSize();
    }

    pub fn getBitDepth(self: VideoMode) u32 {
        return self.platform_video_mode.getBitDepth();
    }

    pub fn getRefreshRate(self: VideoMode) u32 {
        return self.platform_video_mode.getRefreshRate();
    }

    pub fn getDisplay(self: VideoMode) DisplayHandle {
        return .{
            .plaform_display_handle = self.platform_video_mode.getDisplay(),
        };
    }
};

pub const DisplayHandle = struct {
    plaform_display_handle: PlatformDisplayHandle,

    pub fn primary() DisplayHandle {
        return .{
            .plaform_display_handle = PlatformDisplayHandle.primary(),
        };
    }

    pub fn availableDisplays(allocator: std.mem.Allocator) ![]DisplayHandle {
        var displays = try PlatformDisplayHandle.availableDisplays(allocator);
        defer allocator.free(displays);
        var result = std.ArrayList(DisplayHandle).init(allocator);
        defer result.deinit();
        for (displays) |display| {
            try result.append(.{ .plaform_display_handle = display });
        }
        return result.toOwnedSlice();
    }

    pub fn getName(self: DisplayHandle, allocator: std.mem.Allocator) !?[]u8 {
        return self.plaform_display_handle.getName(allocator);
    }

    pub fn getSize(self: DisplayHandle) ?dpi.PhysicalSize {
        return self.plaform_display_handle.getSize();
    }

    pub fn getRefreshRate(self: DisplayHandle) ?u32 {
        return self.plaform_display_handle.getRefreshRate();
    }

    pub fn getPosition(self: DisplayHandle) ?dpi.PhysicalPosition {
        return self.plaform_display_handle.getPosition();
    }

    pub fn getDpi(self: DisplayHandle) ?u32 {
        return self.plaform_display_handle.getDpi();
    }

    pub fn getScaleFactor(self: DisplayHandle) ?f64 {
        return self.plaform_display_handle.getScaleFactor();
    }

    pub fn getVideoModes(self: DisplayHandle, allocator:std.mem.Allocator) ![]VideoMode {
        var modes = try self.plaform_display_handle.getVideoModes(allocator);
        defer allocator.free(modes);

        var result = std.ArrayList(VideoMode).init(allocator);
        defer result.deinit();
        for (modes) |mode| {
            try result.append(.{ .platform_video_mode = mode });
        }
        return result.toOwnedSlice();
    }
};