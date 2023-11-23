const std = @import("std");

const Renderer = @import("Renderer.zig");
const SystemValue = @import("Shader.zig").SystemValue;

const Self = @This();

name: []const u8,
format: Renderer.format.Format = .rgba32float,
/// val for gl, vk and metal, steam output for d3d
location: u32 = 0,
system_value: SystemValue = .undefined,

pub fn eql(self: *const Self, other: *const Self) bool {
    return std.mem.eql(u8, self.name, other.name) and
        self.format == other.format and
        self.location == other.location and
        self.system_value == other.system_value;
}
