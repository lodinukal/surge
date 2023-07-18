const std = @import("std");
const common = @import("../core/common.zig");

pub inline fn validateScaleFactor(factor: f64) bool {
    return std.math.isNormal(factor) and factor > 0;
}

pub inline fn assertScaleFactor(factor: f64) void {
    common.assert(validateScaleFactor(factor), "scale factor of {} was not valid.", .{factor});
}

pub const LogicalPosition = struct {
    const Self = @This();
    x: f64,
    y: f64,

    pub fn init(x: f64, y: f64) Self {
        return Self{ .x = x, .y = y };
    }

    pub fn fromPhysical(physical: PhysicalPosition, scale_factor: f64) Self {
        return physical.toLogical(scale_factor);
    }

    pub fn toPhysical(physical: Self, scale_factor: f64) PhysicalPosition {
        assertScaleFactor(scale_factor);
        const x = @round(physical.x * scale_factor);
        const y = @round(physical.y * scale_factor);
        return PhysicalPosition.init(x, y);
    }
};

pub const PhysicalPosition = struct {
    const Self = @This();
    x: i64,
    y: i64,

    pub fn init(x: i64, y: i64) Self {
        return Self{ .x = x, .y = y };
    }

    pub fn fromLogical(logical: LogicalPosition, scale_factor: f64) Self {
        return logical.toPhysical(scale_factor);
    }

    pub fn toLogical(logical: Self, scale_factor: f64) LogicalPosition {
        assertScaleFactor(scale_factor);
        const x = @divTrunc(logical.x, scale_factor);
        const y = @divTrunc(logical.y, scale_factor);
        return LogicalPosition.init(x, y);
    }
};

pub const Position = union(enum) {
    physical: PhysicalPosition,
    logical: LogicalPosition,

    pub fn initPhysical(x: i64, y: i64) Position {
        return Position{ .physical = PhysicalPosition.init(x, y) };
    }

    pub fn initLogical(x: f64, y: f64) Position {
        return Position{ .logical = LogicalPosition.init(x, y) };
    }

    pub fn toLogical(position: Position, scale_factor: f64) LogicalPosition {
        switch (position) {
            .physical => |physical| return physical.toLogical(scale_factor),
            .logical => |logical| return logical,
        }
    }

    pub fn toPhysical(position: Position, scale_factor: f64) PhysicalPosition {
        switch (position) {
            .physical => |physical| return physical,
            .logical => |logical| return logical.toPhysical(scale_factor),
        }
    }

    pub fn clamp(position: Position, min: Position, max: Position) Position {
        switch (position) {
            .physical => |physical| return physical.clamp(min.physical, max.physical).physical,
            .logical => |logical| return logical.clamp(min.logical, max.logical).logical,
        }
    }
};

pub const LogicalSize = struct {
    const Self = @This();
    width: f64,
    height: f64,

    pub fn init(width: f64, height: f64) Self {
        return Self{ .width = width, .height = height };
    }

    pub fn fromPhysical(physical: PhysicalSize, scale_factor: f64) Self {
        return physical.toLogical(scale_factor);
    }

    pub fn toPhysical(logical: Self, scale_factor: f64) PhysicalSize {
        assertScaleFactor(scale_factor);
        const width = @round(logical.width * scale_factor);
        const height = @round(logical.height * scale_factor);
        return PhysicalSize.init(width, height);
    }
};

pub const PhysicalSize = struct {
    const Self = @This();
    width: i64,
    height: i64,

    pub fn init(width: i64, height: i64) Self {
        return Self{ .width = width, .height = height };
    }

    pub fn fromLogical(logical: LogicalSize, scale_factor: f64) Self {
        return logical.toPhysical(scale_factor);
    }

    pub fn toLogical(physical: Self, scale_factor: f64) LogicalSize {
        assertScaleFactor(scale_factor);
        const width = @divTrunc(physical.width, scale_factor);
        const height = @divTrunc(physical.height, scale_factor);
        return LogicalSize.init(width, height);
    }
};

pub const Size = union(enum) {
    physical: PhysicalSize,
    logical: LogicalSize,

    pub fn initPhysical(width: i64, height: i64) Size {
        return Size{ .physical = PhysicalSize.init(width, height) };
    }

    pub fn initLogical(width: f64, height: f64) Size {
        return Size{ .logical = LogicalSize.init(width, height) };
    }

    pub fn toLogical(size: Size, scale_factor: f64) LogicalSize {
        switch (size) {
            .physical => |physical| return physical.toLogical(scale_factor),
            .logical => |logical| return logical,
        }
    }

    pub fn toPhysical(size: Size, scale_factor: f64) PhysicalSize {
        switch (size) {
            .physical => |physical| return physical,
            .logical => |logical| return logical.toPhysical(scale_factor),
        }
    }

    pub fn clamp(size: Size, min: Size, max: Size) Size {
        switch (size) {
            .physical => |physical| return physical.clamp(min.physical, max.physical).physical,
            .logical => |logical| return logical.clamp(min.logical, max.logical).logical,
        }
    }
};
