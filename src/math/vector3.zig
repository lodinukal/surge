const std = @import("std");

pub fn Vector3(comptime T: type) type {
    return struct {
        const Self = @This();
        x: T = 0,
        y: T = 0,
        z: T = 0,

        pub const is_floating_point = std.meta.trait.isFloat(T);

        pub const zero = Self{ .x = 0, .y = 0, .z = 0 };
        pub const one = Self{ .x = 1, .y = 1, .z = 1 };
        pub const degree45 = Self{ .x = 0.70710678118, .y = 0.70710678118, .z = 0 };

        pub const unit_x = Self{ .x = 1, .y = 0, .z = 0 };
        pub const unit_y = Self{ .x = 0, .y = 1, .z = 0 };
        pub const unit_z = Self{ .x = 0, .y = 0, .z = 1 };

        pub inline fn init(x: ?T, y: ?T, z: ?T) Self {
            return Self{ .x = x orelse 0, .y = y orelse 0, .z = z orelse 0 };
        }

        pub inline fn convert(self: Self, comptime U: type) Vector3(U) {
            const this_floating_point = comptime Self.is_floating_point;
            const other_floating_point = comptime std.meta.trait.isFloat(U);
            if (this_floating_point and other_floating_point) {
                return Vector3(U){
                    .x = @as(U, @floatCast(self.x)),
                    .y = @as(U, @floatCast(self.y)),
                    .z = @as(U, @floatCast(self.z)),
                };
            } else if (this_floating_point and !other_floating_point) {
                return Vector3(U){
                    .x = @as(U, @intFromFloat(self.x)),
                    .y = @as(U, @intFromFloat(self.y)),
                    .z = @as(U, @intFromFloat(self.z)),
                };
            } else if (!this_floating_point and other_floating_point) {
                return Vector3(U){
                    .x = @as(U, @floatFromInt(self.x)),
                    .y = @as(U, @floatFromInt(self.y)),
                    .z = @as(U, @floatFromInt(self.z)),
                };
            } else if (!this_floating_point and !other_floating_point) {
                return Vector3(U){
                    .x = @as(U, @intCast(self.x)),
                    .y = @as(U, @intCast(self.y)),
                    .z = @as(U, @intCast(self.z)),
                };
            }
            return undefined;
        }

        pub inline fn eql(self: Self, other: Self, tolerance: ?T) bool {
            const t = tolerance orelse std.math.floatEps(T);
            return std.math.approxEqRel(self.x, other.x, t) and
                std.math.approxEqRel(self.y, other.y, t) and
                std.math.approxEqRel(self.z, other.z, t);
        }

        pub fn order(self: Self, other: Self) std.math.Order {
            return switch (std.math.order(self.x, other.x)) {
                .eq => switch (std.math.order(self.y, other.y)) {
                    .eq => std.math.order(self.z, other.z),
                    .lt => .lt,
                    .gt => .gt,
                },
                .lt => .lt,
                .gt => .gt,
            };
        }

        pub inline fn add(self: Self, other: Self) Self {
            return Self{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
        }

        pub inline fn sub(self: Self, other: Self) Self {
            return Self{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
        }

        pub inline fn mul(self: Self, other: Self) Self {
            return Self{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
        }

        pub inline fn div(self: Self, other: Self) Self {
            return Self{ .x = self.x / other.x, .y = self.y / other.y, .z = self.z / other.z };
        }

        pub inline fn addAssign(self: *Self, other: Self) void {
            self.x += other.x;
            self.y += other.y;
            self.z += other.z;
        }

        pub inline fn subAssign(self: *Self, other: Self) void {
            self.x -= other.x;
            self.y -= other.y;
            self.z -= other.z;
        }

        pub inline fn mulAssign(self: *Self, other: Self) void {
            self.x *= other.x;
            self.y *= other.y;
            self.z *= other.z;
        }

        pub inline fn divAssign(self: *Self, other: Self) void {
            self.x /= other.x;
            self.y /= other.y;
            self.z /= other.z;
        }

        pub inline fn addScalar(self: Self, other: T) Self {
            return Self{ .x = self.x + other, .y = self.y + other, .z = self.z + other };
        }

        pub inline fn subScalar(self: Self, other: T) Self {
            return Self{ .x = self.x - other, .y = self.y - other, .z = self.z - other };
        }

        pub inline fn mulScalar(self: Self, other: T) Self {
            return Self{ .x = self.x * other, .y = self.y * other, .z = self.z * other };
        }

        pub inline fn divScalar(self: Self, other: T) Self {
            return Self{ .x = self.x / other, .y = self.y / other, .z = self.z / other };
        }

        pub inline fn addScalarAssign(self: *Self, other: T) void {
            self.x += other;
            self.y += other;
            self.z += other;
        }

        pub inline fn subScalarAssign(self: *Self, other: T) void {
            self.x -= other;
            self.y -= other;
            self.z -= other;
        }

        pub inline fn mulScalarAssign(self: *Self, other: T) void {
            self.x *= other;
            self.y *= other;
            self.z *= other;
        }

        pub inline fn divScalarAssign(self: *Self, other: T) void {
            self.x /= other;
            self.y /= other;
            self.z /= other;
        }

        pub inline fn dot(self: Self, other: Self) T {
            return self.x * other.x + self.y * other.y + self.z * other.z;
        }

        pub inline fn cross(self: Self, other: Self) T {
            return Self{
                .x = self.y * other.z - self.z * other.y,
                .y = self.z * other.x - self.x * other.z,
                .z = self.x * other.y - self.y * other.x,
            };
        }

        pub inline fn length(self: Self) T {
            return @sqrt(self.lengthSquared());
        }

        pub inline fn lengthSquared(self: Self) T {
            return self.x * self.x + self.y * self.y + self.z * self.z;
        }

        pub inline fn max(self: Self, other: Self) Self {
            return Self{
                .x = @max(self.x, other.x),
                .y = @max(self.y, other.y),
                .z = @max(self.z, other.z),
            };
        }

        pub inline fn min(self: Self, other: Self) Self {
            return Self{
                .x = @min(self.x, other.x),
                .y = @min(self.y, other.y),
                .z = @min(self.z, other.z),
            };
        }

        pub inline fn clamp(self: Self, minimum: Self, maximum: Self) Self {
            return Self{
                .x = std.math.clamp(self.x, minimum.x, maximum.x),
                .y = std.math.clamp(self.y, minimum.y, maximum.y),
                .z = std.math.clamp(self.z, minimum.z, maximum.z),
            };
        }

        pub inline fn normalise(self: Self) Self {
            return self.div(Self{
                .x = self.length(),
                .y = self.length(),
                .z = self.length(),
            });
        }

        pub inline fn toDirectionAndLength(self: Self) struct { ?Self, f64 } {
            const l = self.length();
            if (l > std.math.floatEps(T)) {
                const one_over_length = 1.0 / l;
                return .{ .{
                    .x = self.x * one_over_length,
                    .y = self.y * one_over_length,
                    .z = self.z * one_over_length,
                }, l };
            } else {
                return .{ null, 0.0 };
            }
        }

        pub inline fn isNearlyZero(self: Self, tolerance: ?T) bool {
            const t = tolerance orelse std.math.floatEps(T);
            return std.math.approxEqRel(self.x, 0, t) and
                std.math.approxEqRel(self.y, 0, t) and
                std.math.approxEqRel(self.z, 0, t);
        }

        pub inline fn round(self: Self) Self {
            return Self{
                .x = @round(self.x),
                .y = @round(self.y),
                .z = @round(self.z),
            };
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try writer.print("Vector3({s}){{{}, {}, {}}}", .{
                @typeName(T),
                self.x,
                self.y,
                self.z,
            });
        }
    };
}
