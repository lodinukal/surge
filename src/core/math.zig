const std = @import("std");

pub fn Point2(comptime T: type) type {
    return struct {
        const Self = @This();
        const is_floating_point = std.meta.trait.isFloat(T);
        x: T,
        y: T,

        pub fn magnitude(self: Self) f32 {
            if (comptime is_floating_point) {
                return @sqrt(self.x * self.x + self.y * self.y);
            } else {
                return @sqrt(@intToFloat(f32, self.x * self.x + self.y * self.y));
            }
        }

        pub fn normalize(self: Self) Self {
            const mag = self.magnitude();
            return if (comptime is_floating_point) Self{
                .x = self.x / mag,
                .y = self.y / mag,
            } else Self{
                .x = @floatToInt(T, @intToFloat(f32, self.x) / mag),
                .y = @floatToInt(T, @intToFloat(f32, self.y) / mag),
            };
        }

        pub fn dot(self: Self, other: Self) f32 {
            return if (comptime is_floating_point) {
                return self.x * other.x + self.y * other.y;
            } else {
                return @intToFloat(
                    f32,
                    self.x * other.x,
                ) + @intToFloat(
                    f32,
                    self.y * other.y,
                );
            };
        }

        pub fn cross(self: Self, other: Self) f32 {
            return if (comptime is_floating_point) {
                return self.x * other.y - self.y * other.x;
            } else {
                return @intToFloat(
                    f32,
                    self.x * other.y,
                ) - @intToFloat(
                    f32,
                    self.y * other.x,
                );
            };
        }

        pub fn add(self: Self, other: Self) Self {
            return Self{
                .x = self.x + other.x,
                .y = self.y + other.y,
            };
        }

        pub fn sub(self: Self, other: Self) Self {
            return Self{
                .x = self.x - other.x,
                .y = self.y - other.y,
            };
        }

        pub fn mul(self: Self, other: Self) Self {
            return Self{
                .x = self.x * other.x,
                .y = self.y * other.y,
            };
        }

        pub fn div(self: Self, other: Self) Self {
            return Self{
                .x = @divFloor(self.x, other.x),
                .y = @divFloor(self.y, other.y),
            };
        }

        pub inline fn convert_to(self: Self, comptime U: type) Point2(U) {
            const other_is_floating_point = comptime std.meta.trait.isFloat(U);
            switch (comptime is_floating_point) {
                true => {
                    switch (other_is_floating_point) {
                        true => return Point2(U){
                            .x = @floatCast(U, self.x),
                            .y = @floatCast(U, self.y),
                        },
                        false => return Point2(U){
                            .x = @floatToInt(U, @intToFloat(f32, self.x)),
                            .y = @floatToInt(U, @intToFloat(f32, self.y)),
                        },
                    }
                },
                false => {
                    switch (other_is_floating_point) {
                        true => return Point2(U){
                            .x = @intToFloat(f32, self.x),
                            .y = @intToFloat(f32, self.y),
                        },
                        false => return Point2(U){
                            .x = @intCast(U, self.x),
                            .y = @intCast(U, self.y),
                        },
                    }
                },
            }
        }
    };
}

test "point2(i8) -> point2(i32)" {
    const p = Point2(i8){ .x = 1, .y = 2 };
    const p2 = p.convert_to(i32);
    try std.testing.expectEqual(@intCast(i32, 1), p2.x);
    try std.testing.expectEqual(@intCast(i32, 2), p2.y);
}

test "point2(i8) -> point2(f32)" {
    const p = Point2(i8){ .x = 1, .y = 2 };
    const p2 = p.convert_to(f32);
    try std.testing.expectEqual(@intToFloat(f32, 1), p2.x);
    try std.testing.expectEqual(@intToFloat(f32, 2), p2.y);
}

pub fn Point3(comptime T: type) type {
    return struct {
        const Self = @This();
        const is_floating_point = std.meta.trait.isFloat(T);
        x: T,
        y: T,
        z: T,

        pub fn magnitude(self: Self) f32 {
            if (comptime is_floating_point) {
                return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
            } else {
                return @sqrt(@intToFloat(f32, self.x * self.x + self.y * self.y + self.z * self.z));
            }
        }

        pub fn normalize(self: Self) Self {
            const mag = self.magnitude();
            return if (comptime is_floating_point) Self{
                .x = self.x / mag,
                .y = self.y / mag,
                .z = self.z / mag,
            } else Self{
                .x = @floatToInt(T, @intToFloat(f32, self.x) / mag),
                .y = @floatToInt(T, @intToFloat(f32, self.y) / mag),
                .z = @floatToInt(T, @intToFloat(f32, self.z) / mag),
            };
        }

        pub fn dot(self: Self, other: Self) f32 {
            return if (comptime is_floating_point) {
                return self.x * other.x + self.y * other.y + self.z * other.z;
            } else {
                return @intToFloat(
                    f32,
                    self.x * other.x,
                ) + @intToFloat(
                    f32,
                    self.y * other.y,
                ) + @intToFloat(
                    f32,
                    self.z * other.z,
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

        pub fn add(self: Self, other: Self) Self {
            return Self{
                .x = self.x + other.x,
                .y = self.y + other.y,
                .z = self.z + other.z,
            };
        }

        pub fn sub(self: Self, other: Self) Self {
            return Self{
                .x = self.x - other.x,
                .y = self.y - other.y,
                .z = self.z - other.z,
            };
        }

        pub fn mul(self: Self, other: Self) Self {
            return Self{
                .x = self.x * other.x,
                .y = self.y * other.y,
                .z = self.z * other.z,
            };
        }

        pub fn div(self: Self, other: Self) Self {
            return Self{
                .x = @divFloor(self.x, other.x),
                .y = @divFloor(self.y, other.y),
                .z = @divFloor(self.z, other.z),
            };
        }

        pub inline fn convert_to(self: Self, comptime U: type) Point3(U) {
            const other_is_floating_point = comptime std.meta.trait.isFloat(U);
            switch (comptime is_floating_point) {
                true => {
                    switch (other_is_floating_point) {
                        true => return Point3(U){
                            .x = @floatCast(U, self.x),
                            .y = @floatCast(U, self.y),
                            .z = @floatCast(U, self.z),
                        },
                        false => return Point3(U){
                            .x = @floatToInt(U, @intToFloat(f32, self.x)),
                            .y = @floatToInt(U, @intToFloat(f32, self.y)),
                            .z = @floatToInt(U, @intToFloat(f32, self.z)),
                        },
                    }
                },
                false => {
                    switch (other_is_floating_point) {
                        true => return Point3(U){
                            .x = @intToFloat(f32, self.x),
                            .y = @intToFloat(f32, self.y),
                            .z = @intToFloat(f32, self.z),
                        },
                        false => return Point3(U){
                            .x = @intCast(U, self.x),
                            .y = @intCast(U, self.y),
                            .z = @intCast(U, self.z),
                        },
                    }
                },
            }
        }
    };
}

test "point3(i8) -> point3(i32)" {
    const p = Point3(i8){ .x = 1, .y = 2, .z = 3 };
    const p2 = p.convert_to(i32);
    try std.testing.expectEqual(@intCast(i32, 1), p2.x);
    try std.testing.expectEqual(@intCast(i32, 2), p2.y);
    try std.testing.expectEqual(@intCast(i32, 3), p2.z);
}

test "point3(i8) -> point3(f32)" {
    const p = Point3(i8){ .x = 1, .y = 2, .z = 3 };
    const p2 = p.convert_to(f32);
    try std.testing.expectEqual(@intToFloat(f32, 1), p2.x);
    try std.testing.expectEqual(@intToFloat(f32, 2), p2.y);
    try std.testing.expectEqual(@intToFloat(f32, 3), p2.z);
}

pub const Point2i = Point2(i32);
pub const Point2f = Point2(f32);
pub const Point3i = Point3(i32);
pub const Point3f = Point3(f32);
