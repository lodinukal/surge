const std = @import("std");

const Renderer = @import("Renderer.zig");
const SystemValue = Renderer.Shader.SystemValue;

const Self = @This();

name: []const u8,
format: Renderer.format.Format = .rgba32float,
/// val for gl, vk and metal, steam output for d3d
location: u32 = 0,
/// hlsl
semantic_index: u32 = 0,
system_value: SystemValue = .undefined,
/// vertex buffer binding slot
slot: u32 = 0,
offset: u32 = 0,
stride: u32 = 0,
instance_divisor: u32 = 0,

pub const VertexFormat = struct {
    attributes: std.ArrayList(Self),

    pub fn init(allocator: std.mem.Allocator) VertexFormat {
        return .{
            .attributes = std.ArrayList(Self).init(allocator),
        };
    }

    pub inline fn appendAttribute(self: *VertexFormat, attribute: Self) !void {
        try self.attributes.append(attribute);
        var last = &self.attributes.items[self.attributes.items.len - 1];

        if (self.attributes.items.len > 1) {
            const previous = self.attributes.items[self.attributes.items.len - 2];
            last.location = previous.location + 1;
            last.offset = previous.offset + previous.getSize();
        } else {
            last.location = 0;
            last.offset = 0;
        }

        var stride: u32 = 0;
        for (self.attributes.items) |attr| {
            stride = @max(stride, stride + attr.getSize());
        }
    }

    pub inline fn getStride(self: *const VertexFormat) u32 {
        return if (self.attributes.items.len == 0) 0 else self.attributes.items[0].stride;
    }

    pub inline fn getStrideFromSlot(self: *const VertexFormat, slot: u32) u32 {
        for (self.attributes.items) |attr| {
            if (attr.slot == slot) return attr.stride;
        }
        return 0;
    }

    pub inline fn setStride(self: *VertexFormat, stride: u32) void {
        for (self.attributes.items) |*attr| {
            attr.stride = stride;
        }
    }

    pub inline fn setStrideForSlot(self: *VertexFormat, slot: u32, stride: u32) void {
        for (self.attributes.items) |*attr| {
            if (attr.slot == slot) attr.stride = stride;
        }
    }

    pub inline fn setSlot(self: *VertexFormat, slot: u32) void {
        for (self.attributes.items) |*attr| {
            attr.slot = slot;
        }
    }

    pub inline fn done(self: *VertexFormat) ![]Self {
        return self.attributes.toOwnedSlice();
    }
};

pub fn eql(self: *const Self, other: *const Self) bool {
    return std.mem.eql(u8, self.name, other.name) and
        self.format == other.format and
        self.location == other.location and
        self.semantic_index == other.semantic_index and
        self.system_value == other.system_value and
        self.slot == other.slot and
        self.offset == other.offset and
        self.stride == other.stride and
        self.instance_divisor == other.instance_divisor;
}

pub fn getSize(self: Self) u32 {
    const attributes = Renderer.format.getFormatAttributes(self.format).?;
    if (attributes.info.supports_vertex) return @divExact(attributes.bit_size, 8);
    return 0;
}
