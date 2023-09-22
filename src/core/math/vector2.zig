const std = @import("std");

const int_point = @import("int_point.zig");

pub fn Vector2(comptime T: type) type {
    if (comptime !std.meta.trait.isFloat(T)) {
        @compileError("Vector2 only supports floating types");
    }

    return struct {
        const Self = @This();
        x: T = 0,
        y: T = 0,

        const zero = Self{ .x = 0, .y = 0 };
        const one = Self{ .x = 1, .y = 1 };
        const degree45 = Self{ .x = 0.70710678118, .y = 0.70710678118 };

        const unit_x = Self{ .x = 1, .y = 0 };
        const unit_y = Self{ .x = 0, .y = 1 };

        pub inline fn init(x: ?T, y: ?T) Self {
            return Self{ .x = x orelse 0, .y = y orelse 0 };
        }

        pub inline fn fromIntPoint(comptime U: type, p: int_point.IntPoint(U)) Self {
            return Self{ .x = @floatFromInt(p.x), .y = @floatFromInt(p.y) };
        }

        pub inline fn eql(self: Self, other: Self, tolerance: ?T) bool {
            const t = tolerance orelse std.math.floatEps(T);
            return std.math.approxEqRel(self.x, other.x, t) and std.math.approxEqRel(self.y, other.y, t);
        }

        pub fn order(self: Self, other: Self) std.math.Order {
            return switch (std.math.order(self.x, other.x)) {
                .eq => std.math.order(self.y, other.y),
                .lt => .lt,
                .gt => .gt,
            };
        }

        pub inline fn add(self: Self, other: Self) Self {
            return Self{ .x = self.x + other.x, .y = self.y + other.y };
        }

        pub inline fn sub(self: Self, other: Self) Self {
            return Self{ .x = self.x - other.x, .y = self.y - other.y };
        }

        pub inline fn mul(self: Self, other: Self) Self {
            return Self{ .x = self.x * other.x, .y = self.y * other.y };
        }

        pub inline fn div(self: Self, other: Self) Self {
            return Self{ .x = self.x / other.x, .y = self.y / other.y };
        }

        pub inline fn addAssign(self: *Self, other: Self) void {
            self.x += other.x;
            self.y += other.y;
        }

        pub inline fn subAssign(self: *Self, other: Self) void {
            self.x -= other.x;
            self.y -= other.y;
        }

        pub inline fn mulAssign(self: *Self, other: Self) void {
            self.x *= other.x;
            self.y *= other.y;
        }

        pub inline fn divAssign(self: *Self, other: Self) void {
            self.x /= other.x;
            self.y /= other.y;
        }

        pub inline fn addScalar(self: Self, other: T) Self {
            return Self{ .x = self.x + other, .y = self.y + other };
        }

        pub inline fn subScalar(self: Self, other: T) Self {
            return Self{ .x = self.x - other, .y = self.y - other };
        }

        pub inline fn mulScalar(self: Self, other: T) Self {
            return Self{ .x = self.x * other, .y = self.y * other };
        }

        pub inline fn divScalar(self: Self, other: T) Self {
            return Self{ .x = self.x / other, .y = self.y / other };
        }

        pub inline fn addScalarAssign(self: *Self, other: T) void {
            self.x += other;
            self.y += other;
        }

        pub inline fn subScalarAssign(self: *Self, other: T) void {
            self.x -= other;
            self.y -= other;
        }

        pub inline fn mulScalarAssign(self: *Self, other: T) void {
            self.x *= other;
            self.y *= other;
        }

        pub inline fn divScalarAssign(self: *Self, other: T) void {
            self.x /= other;
            self.y /= other;
        }

        pub inline fn dot(self: Self, other: Self) T {
            return self.x * other.x + self.y * other.y;
        }

        pub inline fn cross(self: Self, other: Self) T {
            return self.x * other.y - self.y * other.x;
        }

        pub inline fn length(self: Self) T {
            return @sqrt(self.lengthSquared());
        }

        pub inline fn lengthSquared(self: Self) T {
            return self.x * self.x + self.y * self.y;
        }

        pub inline fn max(self: Self, other: Self) Self {
            return Self{ .x = @max(self.x, other.x), .y = @max(self.y, other.y) };
        }

        pub inline fn min(self: Self, other: Self) Self {
            return Self{ .x = @min(self.x, other.x), .y = @min(self.y, other.y) };
        }

        pub inline fn clamp(self: Self, minimum: Self, maximum: Self) Self {
            return Self{
                .x = std.math.clamp(self.x, minimum.x, maximum.x),
                .y = std.math.clamp(self.y, minimum.y, maximum.y),
            };
        }

        pub inline fn normalise(self: Self) Self {
            return self.div(Self{
                .x = self.length(),
                .y = self.length(),
            });
        }

        pub inline fn getRotated(self: Self, degrees: T) Self {
            const radians = std.math.degreesToRadians(T, degrees);
            const cos = @cos(radians);
            const sin = @sin(radians);
            return Self{
                .x = self.x * cos - self.y * sin,
                .y = self.x * sin + self.y * cos,
            };
        }

        pub inline fn toDirectionAndLength(self: Self) struct { ?Self, f64 } {
            const l = self.length();
            if (l > std.math.floatEps(T)) {
                const one_over_length = 1.0 / l;
                return .{ .{
                    .x = self.x * one_over_length,
                    .y = self.y * one_over_length,
                }, l };
            } else {
                return .{ null, 0.0 };
            }
        }

        pub inline fn isNearlyZero(self: Self, tolerance: ?T) bool {
            const t = tolerance orelse std.math.floatEps(T);
            return std.math.approxEqRel(self.x, 0, t) and std.math.approxEqRel(self.y, 0, t);
        }

        pub inline fn round(self: Self) Self {
            return Self{ .x = @round(self.x), .y = @round(self.y) };
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try writer.print("Vector2({s}){{{}, {}}}", .{ @typeName(T), self.x, self.y });
        }
    };
}
