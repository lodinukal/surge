const std = @import("std");

pub fn IntPoint(comptime T: type) type {
    if (comptime !std.meta.trait.isIntegral(T)) {
        @compileError("IntPoint only supports integral types");
    }

    return struct {
        x: T = 0,
        y: T = 0,

        const Self = @This();

        const zero_value: Self = .{ .x = 0, .y = 0 };

        pub fn init(x: ?T, y: ?T) Self {
            return .{ .x = x orelse 0, .y = y orelse 0 };
        }

        pub fn convert(comptime U: type) IntPoint(U) {
            if (comptime std.meta.trait.isIntegral(U)) {
                return IntPoint(U).init(Self.x, Self.y);
            } else {
                @compileError("IntPoint.convert only supports integral types");
            }
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y;
        }

        pub fn order(self: Self, other: Self) std.math.Order {
            return switch (std.math.order(self.x, other.x)) {
                .eq => std.math.order(self.y, other.y),
                .lt => .lt,
                .gt => .gt,
            };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{ .x = self.x + other.x, .y = self.y + other.y };
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{ .x = self.x - other.x, .y = self.y - other.y };
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{ .x = self.x * other.x, .y = self.y * other.y };
        }

        pub fn div(self: Self, other: Self) Self {
            return .{
                .x = @divTrunc(self.x, other.x),
                .y = @divTrunc(self.y, other.y),
            };
        }

        pub fn rem(self: Self, other: Self) Self {
            return .{ .x = self.x % other.x, .y = self.y % other.y };
        }

        pub fn neg(self: Self) Self {
            return .{ .x = -self.x, .y = -self.y };
        }

        pub fn add_assign(self: *Self, other: Self) void {
            self.x += other.x;
            self.y += other.y;
        }

        pub fn sub_assign(self: *Self, other: Self) void {
            self.x -= other.x;
            self.y -= other.y;
        }

        pub fn mul_assign(self: *Self, other: Self) void {
            self.x *= other.x;
            self.y *= other.y;
        }

        pub fn div_assign(self: *Self, other: Self) void {
            self.x = @divTrunc(self.x, other.x);
            self.y = @divTrunc(self.y, other.y);
        }

        pub fn rem_assign(self: *Self, other: Self) void {
            self.x %= other.x;
            self.y %= other.y;
        }

        pub fn neg_assign(self: *Self) void {
            self.x = -self.x;
            self.y = -self.y;
        }

        pub fn add_scalar(self: Self, other: T) Self {
            return .{ .x = self.x + other, .y = self.y + other };
        }

        pub fn sub_scalar(self: Self, other: T) Self {
            return .{ .x = self.x - other, .y = self.y - other };
        }

        pub fn mul_scalar(self: Self, other: T) Self {
            return .{ .x = self.x * other, .y = self.y * other };
        }

        pub fn div_scalar(self: Self, other: T) Self {
            return .{
                .x = @divTrunc(self.x, other),
                .y = @divTrunc(self.y, other),
            };
        }

        pub fn rem_scalar(self: Self, other: T) Self {
            return .{ .x = self.x % other, .y = self.y % other };
        }

        pub fn add_scalar_assign(self: *Self, other: T) void {
            self.x += other;
            self.y += other;
        }

        pub fn sub_scalar_assign(self: *Self, other: T) void {
            self.x -= other;
            self.y -= other;
        }

        pub fn mul_scalar_assign(self: *Self, other: T) void {
            self.x *= other;
            self.y *= other;
        }

        pub fn div_scalar_assign(self: *Self, other: T) void {
            self.x = @divTrunc(self.x, other);
            self.y = @divTrunc(self.y, other);
        }

        pub fn rem_scalar_assign(self: *Self, other: T) void {
            self.x %= other;
            self.y %= other;
        }

        pub fn max(self: Self, other: Self) Self {
            return .{
                .x = @max(self.x, other.x),
                .y = @max(self.y, other.y),
            };
        }

        pub fn min(self: Self, other: Self) Self {
            return .{
                .x = @min(self.x, other.x),
                .y = @min(self.y, other.y),
            };
        }

        pub fn abs(self: Self) Self {
            return .{ .x = std.math.absInt(self.x), .y = std.math.absInt(self.y) };
        }

        pub fn clamp(self: Self, minimum: Self, maximum: Self) Self {
            return .{
                .x = std.math.clamp(self.x, minimum.x, maximum.x),
                .y = std.math.clamp(self.y, minimum.y, maximum.y),
            };
        }

        pub fn clamp_scalar(self: Self, minimum: T, maximum: T) Self {
            return .{
                .x = std.math.clamp(self.x, minimum, maximum),
                .y = std.math.clamp(self.y, minimum, maximum),
            };
        }

        pub fn magnitude(self: Self) T {
            const f: f64 = @floatFromInt(self.size_squared());
            return @intFromFloat(@trunc(@sqrt(f)));
        }

        pub fn size_squared(self: Self) T {
            return self.x * self.x + self.y * self.y;
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            try writer.print("IntPoint({s}){{{}, {}}}", .{ @typeName(T), self.x, self.y });
        }
    };
}
