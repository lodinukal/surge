const std = @import("std");

const point = @import("point.zig");

pub fn Rect2(comptime T: type) type {
    return struct {
        const Self = @This();
        const U = point.Point2(T);
        const is_floating_point = U.is_floating_point;
        position: U,
        size: U,

        pub fn from_components(position: U, size: U) Self {
            return Self{ .position = position, .size = size };
        }

        pub fn from_min_max(min: U, max: U) Self {
            return Self{ .position = min, .size = max.sub(min) };
        }

        pub fn area(self: Self) T {
            return self.size.x * self.size.y;
        }

        pub fn get_center(self: Self) U {
            return self.position.add(self.size.div_scalar(2));
        }

        pub fn contains(self: Self, check: U) bool {
            return check.x >= self.position.x and check.x < self.position.x + self.size.x and
                check.y >= self.position.y and check.y < self.position.y + self.size.y;
        }

        pub fn contains_rect(self: Self, check: Self) bool {
            return check.position.x >= self.position.x and check.position.x + check.size.x <= self.position.x + self.size.x and
                check.position.y >= self.position.y and check.position.y + check.size.y <= self.position.y + self.size.y;
        }

        pub fn intersects(self: Self, check: Self) bool {
            return check.position.x < self.position.x + self.size.x and check.position.x + check.size.x > self.position.x and
                check.position.y < self.position.y + self.size.y and check.position.y + check.size.y > self.position.y;
        }

        pub fn intersection(self: Self, check: Self) Self {
            if (self.intersects(check)) {
                const x = @max(self.position.x, check.position.x);
                const y = @max(self.position.y, check.position.y);
                const width = @min(self.position.x + self.size.x, check.position.x + check.size.x) - x;
                const height = @min(self.position.y + self.size.y, check.position.y + check.size.y) - y;
                return Self{ .position = U{ .x = x, .y = y }, .size = U{ .x = width, .y = height } };
            } else {
                return Self{ .position = U{ .x = 0, .y = 0 }, .size = U{ .x = 0, .y = 0 } };
            }
        }
    };
}

pub fn Rect3(comptime T: type) type {
    return struct {
        const Self = @This();
        const U = point.Point3(T);
        const is_floating_point = U.is_floating_point;
        position: U,
        size: U,

        pub fn from_components(position: U, size: U) Self {
            return Self{ .position = position, .size = size };
        }

        pub fn from_min_max(min: U, max: U) Self {
            return Self{ .position = min, .size = max.sub(min) };
        }

        pub fn area(self: Self) T {
            return self.size.x * self.size.y * self.size.z;
        }

        pub fn get_center(self: Self) U {
            return self.position.add(self.size.div_scalar(2));
        }

        pub fn contains(self: Self, check: U) bool {
            return check.x >= self.position.x and check.x < self.position.x + self.size.x and
                check.y >= self.position.y and check.y < self.position.y + self.size.y and
                check.z >= self.position.z and check.z < self.position.z + self.size.z;
        }

        pub fn contains_rect(self: Self, check: Self) bool {
            return check.position.x >= self.position.x and check.position.x + check.size.x <= self.position.x + self.size.x and
                check.position.y >= self.position.y and check.position.y + check.size.y <= self.position.y + self.size.y and
                check.position.z >= self.position.z and check.position.z + check.size.z <= self.position.z + self.size.z;
        }

        pub fn intersects(self: Self, check: Self) bool {
            return check.position.x < self.position.x + self.size.x and check.position.x + check.size.x > self.position.x and
                check.position.y < self.position.y + self.size.y and check.position.y + check.size.y > self.position.y and
                check.position.z < self.position.z + self.size.z and check.position.z + check.size.z > self.position.z;
        }

        pub fn intersection(self: Self, check: Self) Self {
            if (self.intersects(check)) {
                const x = @max(self.position.x, check.position.x);
                const y = @max(self.position.y, check.position.y);
                const z = @max(self.position.z, check.position.z);
                const width = @min(self.position.x + self.size.x, check.position.x + check.size.x) - x;
                const height = @min(self.position.y + self.size.y, check.position.y + check.size.y) - y;
                const depth = @min(self.position.z + self.size.z, check.position.z + check.size.z) - z;
                return Self{ .position = U{ .x = x, .y = y, .z = z }, .size = U{ .x = width, .y = height, .z = depth } };
            } else {
                return Self{ .position = U{ .x = 0, .y = 0, .z = 0 }, .size = U{ .x = 0, .y = 0, .z = 0 } };
            }
        }
    };
}

pub const Rect2f = Rect2(f32);
pub const Rect2i = Rect2(i32);

pub const Rect3f = Rect3(f32);
pub const Rect3i = Rect3(i32);

test "rect" {
    std.testing.refAllDeclsRecursive(@This());

    const rect = Rect2f.from_components(point.Point2f{ .x = 0, .y = 0 }, point.Point2f{ .x = 10, .y = 10 });
    try std.testing.expectEqual(@as(f32, @floatCast(100.0)), rect.area());
    try std.testing.expectEqual(point.Point2f{ .x = 5, .y = 5 }, rect.get_center());
    try std.testing.expect(rect.contains(point.Point2f{ .x = 5, .y = 5 }));
}
