const std = @import("std");

const common = @import("../../core/common.zig");

const platform = @import("platform_impl.zig");
const event = @import("../event.zig");
const event_loop = @import("../event_loop.zig");

pub const PumpStatus = union(enum) {
    @"continue",
    exit: i32,
};
