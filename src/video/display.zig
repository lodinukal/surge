const std = @import("std");

const platform = @import("./platform.zig");

pub const VideoMode = struct {
    platform_video_mode: platform.impl.display,
};
