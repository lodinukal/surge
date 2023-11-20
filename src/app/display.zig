const std = @import("std");

pub const DisplayMode = struct {
    resolution: [2]u32,
    refresh_rate: u32,
};
