const std = @import("std");

pub fn Vec2(comptime T: type) type {
    return struct {
        const Self = @This();
        const is_floating_point = std.meta.trait.isFloat(T);
        x: T,
        y: T,

        pub fn init(x: T, y: T) Self {
            return Self{
                .x = x,
                .y = y,
            };
        }

        pub fn zero() Self {
            return init(0, 0);
        }

        pub fn magnitude(self: Self) f32 {
            if (comptime is_floating_point) {
                return @sqrt(self.x * self.x + self.y * self.y);
            } else {
                return @sqrt(@as(f32, @floatFromInt(self.x * self.x + self.y * self.y)));
            }
        }

        pub fn normalize(self: Self) Self {
            const mag = self.magnitude();
            return if (comptime is_floating_point) Self{
                .x = self.x / mag,
                .y = self.y / mag,
            } else Self{
                .x = @as(T, @intFromFloat(@as(f32, @floatFromInt(self.x)) / mag)),
                .y = @as(T, @intFromFloat(@as(f32, @floatFromInt(self.y)) / mag)),
            };
        }

        pub fn dot(self: Self, other: Self) f32 {
            return if (comptime is_floating_point) {
                return self.x * other.x + self.y * other.y;
            } else {
                return @as(
                    f32,
                    @floatFromInt(self.x * other.x),
                ) + @as(
                    f32,
                    @floatFromInt(self.y * other.y),
                );
            };
        }

        pub fn cross(self: Self, other: Self) f32 {
            return if (comptime is_floating_point) {
                return self.x * other.y - self.y * other.x;
            } else {
                return @as(
                    f32,
                    @floatFromInt(self.x * other.y),
                ) - @as(
                    f32,
                    @floatFromInt(self.y * other.x),
                );
            };
        }

        pub fn neg(self: Self) Self {
            return Self{
                .x = -self.x,
                .y = -self.y,
            };
        }

        pub fn add(self: Self, other: Self) Self {
            return Self{
                .x = self.x + other.x,
                .y = self.y + other.y,
            };
        }

        pub fn add_scalar(self: Self, other: T) Self {
            return Self{
                .x = self.x + other,
                .y = self.y + other,
            };
        }

        pub fn sub(self: Self, other: Self) Self {
            return Self{
                .x = self.x - other.x,
                .y = self.y - other.y,
            };
        }

        pub fn sub_scalar(self: Self, other: T) Self {
            return Self{
                .x = self.x - other,
                .y = self.y - other,
            };
        }

        pub fn mul(self: Self, other: Self) Self {
            return Self{
                .x = self.x * other.x,
                .y = self.y * other.y,
            };
        }

        pub fn mul_scalar(self: Self, other: T) Self {
            return Self{
                .x = self.x * other,
                .y = self.y * other,
            };
        }

        pub fn div(self: Self, other: Self) Self {
            return Self{
                .x = @divFloor(self.x, other.x),
                .y = @divFloor(self.y, other.y),
            };
        }

        pub fn div_scalar(self: Self, other: T) Self {
            return Self{
                .x = @divFloor(self.x, other),
                .y = @divFloor(self.y, other),
            };
        }

        pub inline fn convert_to(self: Self, comptime U: type) Vec2(U) {
            const other_is_floating_point = comptime std.meta.trait.isFloat(U);
            switch (comptime is_floating_point) {
                true => {
                    switch (other_is_floating_point) {
                        true => return Vec2(U){
                            .x = @as(U, @floatCast(self.x)),
                            .y = @as(U, @floatCast(self.y)),
                        },
                        false => return Vec2(U){
                            .x = @as(U, @intFromFloat(@as(f32, @floatFromInt(self.x)))),
                            .y = @as(U, @intFromFloat(@as(f32, @floatFromInt(self.y)))),
                        },
                    }
                },
                false => {
                    switch (other_is_floating_point) {
                        true => return Vec2(U){
                            .x = @as(f32, @floatFromInt(self.x)),
                            .y = @as(f32, @floatFromInt(self.y)),
                        },
                        false => return Vec2(U){
                            .x = @as(U, @intCast(self.x)),
                            .y = @as(U, @intCast(self.y)),
                        },
                    }
                },
            }
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y;
        }
    };
}

test "point2(i8) -> point2(i32)" {
    const p = Vec2(i8){ .x = 1, .y = 2 };
    const p2 = p.convert_to(i32);
    try std.testing.expectEqual(@as(i32, @intCast(1)), p2.x);
    try std.testing.expectEqual(@as(i32, @intCast(2)), p2.y);
}

test "point2(i8) -> point2(f32)" {
    const p = Vec2(i8){ .x = 1, .y = 2 };
    const p2 = p.convert_to(f32);
    try std.testing.expectEqual(@as(f32, @floatFromInt(1)), p2.x);
    try std.testing.expectEqual(@as(f32, @floatFromInt(2)), p2.y);
}

pub fn Vec3(comptime T: type) type {
    return struct {
        const Self = @This();
        const is_floating_point = std.meta.trait.isFloat(T);
        x: T,
        y: T,
        z: T,

        pub fn init(x: T, y: T, z: T) Self {
            return Self{
                .x = x,
                .y = y,
                .z = z,
            };
        }

        pub fn zero() Self {
            return init(0, 0, 0);
        }

        pub fn magnitude(self: Self) f32 {
            if (comptime is_floating_point) {
                return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
            } else {
                return @sqrt(@as(f32, @floatFromInt(self.x * self.x + self.y * self.y + self.z * self.z)));
            }
        }

        pub fn normalize(self: Self) Self {
            const mag = self.magnitude();
            return if (comptime is_floating_point) Self{
                .x = self.x / mag,
                .y = self.y / mag,
                .z = self.z / mag,
            } else Self{
                .x = @as(T, @intFromFloat(@as(f32, @floatFromInt(self.x)) / mag)),
                .y = @as(T, @intFromFloat(@as(f32, @floatFromInt(self.y)) / mag)),
                .z = @as(T, @intFromFloat(@as(f32, @floatFromInt(self.z)) / mag)),
            };
        }

        pub fn dot(self: Self, other: Self) f32 {
            return if (comptime is_floating_point) {
                return self.x * other.x + self.y * other.y + self.z * other.z;
            } else {
                return @as(
                    f32,
                    @floatFromInt(self.x * other.x),
                ) + @as(
                    f32,
                    @floatFromInt(self.y * other.y),
                ) + @as(
                    f32,
                    @floatFromInt(self.z * other.z),
                );
            };
        }

        pub fn cross(self: Self, other: Self) Self {
            return Self{
                .x = self.y * other.z - self.z * other.y,
                .y = self.z * other.x - self.x * other.z,
                .z = self.x * other.y - self.y * other.x,
            };
        }

        pub fn neg(self: Self) Self {
            return Self{
                .x = -self.x,
                .y = -self.y,
                .z = -self.z,
            };
        }

        pub fn add(self: Self, other: Self) Self {
            return Self{
                .x = self.x + other.x,
                .y = self.y + other.y,
                .z = self.z + other.z,
            };
        }

        pub fn add_scalar(self: Self, other: T) Self {
            return Self{
                .x = self.x + other,
                .y = self.y + other,
                .z = self.z + other,
            };
        }

        pub fn sub(self: Self, other: Self) Self {
            return Self{
                .x = self.x - other.x,
                .y = self.y - other.y,
                .z = self.z - other.z,
            };
        }

        pub fn sub_scalar(self: Self, other: T) Self {
            return Self{
                .x = self.x - other,
                .y = self.y - other,
                .z = self.z - other,
            };
        }

        pub fn mul(self: Self, other: Self) Self {
            return Self{
                .x = self.x * other.x,
                .y = self.y * other.y,
                .z = self.z * other.z,
            };
        }

        pub fn mul_scalar(self: Self, other: T) Self {
            return Self{
                .x = self.x * other,
                .y = self.y * other,
                .z = self.z * other,
            };
        }

        pub fn div(self: Self, other: Self) Self {
            return Self{
                .x = @divFloor(self.x, other.x),
                .y = @divFloor(self.y, other.y),
                .z = @divFloor(self.z, other.z),
            };
        }

        pub fn div_scalar(self: Self, other: T) Self {
            return Self{
                .x = @divFloor(self.x, other),
                .y = @divFloor(self.y, other),
                .z = @divFloor(self.z, other),
            };
        }

        pub inline fn convert_to(self: Self, comptime U: type) Vec3(U) {
            const other_is_floating_point = comptime std.meta.trait.isFloat(U);
            switch (comptime is_floating_point) {
                true => {
                    switch (other_is_floating_point) {
                        true => return Vec3(U){
                            .x = @as(U, @floatCast(self.x)),
                            .y = @as(U, @floatCast(self.y)),
                            .z = @as(U, @floatCast(self.z)),
                        },
                        false => return Vec3(U){
                            .x = @as(U, @intFromFloat(@as(f32, @floatFromInt(self.x)))),
                            .y = @as(U, @intFromFloat(@as(f32, @floatFromInt(self.y)))),
                            .z = @as(U, @intFromFloat(@as(f32, @floatFromInt(self.z)))),
                        },
                    }
                },
                false => {
                    switch (other_is_floating_point) {
                        true => return Vec3(U){
                            .x = @as(f32, @floatFromInt(self.x)),
                            .y = @as(f32, @floatFromInt(self.y)),
                            .z = @as(f32, @floatFromInt(self.z)),
                        },
                        false => return Vec3(U){
                            .x = @as(U, @intCast(self.x)),
                            .y = @as(U, @intCast(self.y)),
                            .z = @as(U, @intCast(self.z)),
                        },
                    }
                },
            }
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y and self.z == other.z;
        }
    };
}

test "point3(i8) -> point3(i32)" {
    const p = Vec3(i8){ .x = 1, .y = 2, .z = 3 };
    const p2 = p.convert_to(i32);
    try std.testing.expectEqual(@as(i32, @intCast(1)), p2.x);
    try std.testing.expectEqual(@as(i32, @intCast(2)), p2.y);
    try std.testing.expectEqual(@as(i32, @intCast(3)), p2.z);
}

test "point3(i8) -> point3(f32)" {
    const p = Vec3(i8){ .x = 1, .y = 2, .z = 3 };
    const p2 = p.convert_to(f32);
    try std.testing.expectEqual(@as(f32, @floatFromInt(1)), p2.x);
    try std.testing.expectEqual(@as(f32, @floatFromInt(2)), p2.y);
    try std.testing.expectEqual(@as(f32, @floatFromInt(3)), p2.z);
}

pub const Vec2i = Vec2(i32);
pub const Vec2f = Vec2(f32);
pub const Vec3i = Vec3(i32);
pub const Vec3f = Vec3(f32);
