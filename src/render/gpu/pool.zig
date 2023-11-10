const std = @import("std");

pub fn Handle(comptime T: type) type {
    _ = T;
    return packed struct(u32) {
        index: u16,
        generation: u16,
    };
}

pub fn Pool(comptime T: type, comptime size: u16) type {
    return struct {
        const Self = @This();
        pub const Size = size;
        pub const Hot = T.Hot;
        pub const Cold = T.Cold;

        generations: std.BoundedArray(u16, size),
        hot_list: std.BoundedArray(Hot, size),
        cold_list: std.BoundedArray(Cold, size),

        free_list: std.BoundedArray(u16, size),

        pub fn init() Self {
            return .{
                .generations = std.BoundedArray(u16, size){},
                .hot_list = std.BoundedArray(Hot, size){},
                .cold_list = std.BoundedArray(Cold, size){},
                .free_list = std.BoundedArray(u16, size){},
            };
        }

        pub fn handleValid(self: *const Self, handle: Handle(T)) bool {
            if (handle.index >= Size) {
                return false;
            }
            if (self.generations.len <= handle.index) {
                return false;
            }
            if (self.generations.get(handle.index) != handle.generation) {
                return false;
            }
            return true;
        }

        pub fn getHot(self: *const Self, handle: Handle(T)) ?Hot {
            if (!self.handleValid(handle)) {
                return null;
            }
            return self.hot_list.get(handle.index);
        }

        pub fn getCold(self: *const Self, handle: Handle(T)) ?Cold {
            if (!self.handleValid(handle)) {
                return null;
            }
            return self.cold_list.get(handle.index);
        }

        pub fn put(self: *Self, hot: Hot, cold: Cold) !Handle(T) {
            var index: u16 = 0;
            if (self.free_list.len > 0) {
                index = self.free_list.pop();
            } else {
                index = self.generations.len;
                try self.generations.append(0);
                _ = try self.hot_list.addOne();
                _ = try self.cold_list.addOne();
            }
            self.generations.slice()[index] += 1;
            self.hot_list.slice()[index] = hot;
            self.cold_list.slice()[index] = cold;
            return .{ .index = index, .generation = self.generations.get(index) };
        }

        pub fn remove(self: *Self, handle: Handle(T)) !void {
            if (!self.handleValid(handle)) {
                return;
            }
            self.generations.slice()[handle.index] += 1;
            try self.free_list.append(handle.index);
        }
    };
}

test "Pool" {
    var pool = Pool(struct {
        pub const Hot = u8;
        pub const Cold = u16;
    }, 4).init();

    var handle1 = try pool.put(1, 2);
    var handle2 = try pool.put(3, 4);

    var hot = pool.getHot(handle1);
    var cold = pool.getCold(handle1);

    try std.testing.expectEqual(@as(?u8, 1), hot);
    try std.testing.expectEqual(@as(?u16, 2), cold);

    try std.testing.expectEqual(@as(?u8, 3), pool.getHot(handle2));
    try std.testing.expectEqual(@as(?u16, 4), pool.getCold(handle2));

    try pool.remove(handle1);

    try std.testing.expectEqual(@as(u3, 1), pool.free_list.len);

    try std.testing.expectEqual(@as(?u8, null), pool.getHot(handle1));
    try std.testing.expectEqual(@as(?u16, null), pool.getCold(handle1));

    try std.testing.expectEqual(@as(?u8, 3), pool.getHot(handle2));
    try std.testing.expectEqual(@as(?u16, 4), pool.getCold(handle2));

    var handle3 = try pool.put(5, 6);

    try std.testing.expectEqual(@as(u3, 0), pool.free_list.len);
    try std.testing.expectEqual(@as(u16, handle1.index), handle3.index);
}
