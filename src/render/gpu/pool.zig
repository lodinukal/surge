const std = @import("std");

pub fn Handle(comptime T: type) type {
    _ = T;
    return packed struct(u48) {
        index: u32,
        generation: u16,

        pub fn as(self: @This(), comptime U: type) Handle(U) {
            return .{
                .index = self.index,
                .generation = self.generation,
            };
        }
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

        free_list: std.BoundedArray(u32, size),

        pub fn init() Self {
            return .{
                .generations = std.BoundedArray(u16, size){},
                .hot_list = std.BoundedArray(Hot, size){},
                .cold_list = std.BoundedArray(Cold, size){},
                .free_list = std.BoundedArray(u32, size){},
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

        pub fn getHot(self: *const Self, handle: Handle(T)) ?*const Hot {
            if (!self.handleValid(handle)) {
                return null;
            }
            return &self.hot_list.buffer[handle.index];
        }

        pub fn getCold(self: *const Self, handle: Handle(T)) ?*const Cold {
            if (!self.handleValid(handle)) {
                return null;
            }
            return &self.cold_list.buffer[handle.index];
        }

        pub fn getHotMutable(self: *Self, handle: Handle(T)) ?*Hot {
            if (!self.handleValid(handle)) {
                return null;
            }
            return &self.hot_list.buffer[handle.index];
        }

        pub fn getColdMutable(self: *Self, handle: Handle(T)) ?*Cold {
            if (!self.handleValid(handle)) {
                return null;
            }
            return &self.cold_list.buffer[handle.index];
        }

        pub fn put(self: *Self, hot: Hot, cold: Cold) !Handle(T) {
            var index: u32 = 0;
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
    var hot = pool.getHot(handle1);
    var cold = pool.getCold(handle1);
    var handle2 = try pool.put(3, 4);

    // var hot = pool.getHot(handle1);
    // var cold = pool.getCold(handle1);

    try std.testing.expectEqual(@as(u8, 1), hot.?.*);
    try std.testing.expectEqual(@as(u16, 2), cold.?.*);

    try std.testing.expectEqual(@as(u8, 3), pool.getHot(handle2).?.*);
    try std.testing.expectEqual(@as(u16, 4), pool.getCold(handle2).?.*);

    try pool.remove(handle1);

    try std.testing.expectEqual(@as(u3, 1), pool.free_list.len);

    try std.testing.expectEqual(@as(?*const u8, null), pool.getHot(handle1));
    try std.testing.expectEqual(@as(?*const u16, null), pool.getCold(handle1));

    try std.testing.expectEqual(@as(u8, 3), pool.getHot(handle2).?.*);
    try std.testing.expectEqual(@as(u16, 4), pool.getCold(handle2).?.*);

    var handle3 = try pool.put(5, 6);

    try std.testing.expectEqual(@as(u3, 0), pool.free_list.len);
    try std.testing.expectEqual(@as(u32, handle1.index), handle3.index);
}

pub fn DynamicPool(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Hot = T.Hot;
        pub const Cold = T.Cold;

        allocator: std.mem.Allocator,
        generations: std.ArrayListUnmanaged(u16),
        hot_list: std.ArrayListUnmanaged(Hot),
        cold_list: std.ArrayListUnmanaged(Cold),

        free_list: std.ArrayListUnmanaged(usize),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .generations = std.ArrayListUnmanaged(u16){},
                .hot_list = std.ArrayListUnmanaged(Hot){},
                .cold_list = std.ArrayListUnmanaged(Cold){},
                .free_list = std.ArrayListUnmanaged(usize){},
            };
        }

        pub fn deinit(self: *Self) void {
            self.generations.deinit(self.allocator);
            self.hot_list.deinit(self.allocator);
            self.cold_list.deinit(self.allocator);
            self.free_list.deinit(self.allocator);
        }

        pub fn capacity(self: *const Self) usize {
            return self.generations.capacity;
        }

        pub fn handleValid(self: *const Self, handle: Handle(T)) bool {
            if (handle.index >= self.capacity()) {
                return false;
            }
            if (self.generations.items.len <= handle.index) {
                return false;
            }
            if (self.generations.items[handle.index] != handle.generation) {
                return false;
            }
            return true;
        }

        pub fn getHot(self: *const Self, handle: Handle(T)) ?Hot {
            if (!self.handleValid(handle)) {
                return null;
            }
            return self.hot_list.items[handle.index];
        }

        pub fn getCold(self: *const Self, handle: Handle(T)) ?Cold {
            if (!self.handleValid(handle)) {
                return null;
            }
            return self.cold_list.items[handle.index];
        }

        pub fn put(self: *Self, hot: Hot, cold: Cold) !Handle(T) {
            var index: usize = 0;
            if (self.free_list.items.len > 0) {
                index = self.free_list.pop();
            } else {
                index = self.generations.items.len;
                try self.generations.append(self.allocator, 0);
                _ = try self.hot_list.addOne(self.allocator);
                _ = try self.cold_list.addOne(self.allocator);
            }
            self.generations.items[index] += 1;
            self.hot_list.items[index] = hot;
            self.cold_list.items[index] = cold;
            return .{ .index = @intCast(index), .generation = self.generations.items[index] };
        }

        pub fn remove(self: *Self, handle: Handle(T)) !void {
            if (!self.handleValid(handle)) {
                return;
            }
            self.generations.items[handle.index] += 1;
            try self.free_list.append(self.allocator, handle.index);
        }
    };
}

test "DynamicPool" {
    var pool = DynamicPool(struct {
        pub const Hot = u8;
        pub const Cold = u16;
    }).init(std.testing.allocator);
    defer pool.deinit();

    var handle1 = try pool.put(1, 2);
    var handle2 = try pool.put(3, 4);

    var hot = pool.getHot(handle1);
    var cold = pool.getCold(handle1);

    try std.testing.expectEqual(@as(?u8, 1), hot);
    try std.testing.expectEqual(@as(?u16, 2), cold);

    try std.testing.expectEqual(@as(?u8, 3), pool.getHot(handle2));
    try std.testing.expectEqual(@as(?u16, 4), pool.getCold(handle2));

    try pool.remove(handle1);

    try std.testing.expectEqual(@as(usize, 1), pool.free_list.items.len);

    try std.testing.expectEqual(@as(?u8, null), pool.getHot(handle1));
    try std.testing.expectEqual(@as(?u16, null), pool.getCold(handle1));

    try std.testing.expectEqual(@as(?u8, 3), pool.getHot(handle2));
    try std.testing.expectEqual(@as(?u16, 4), pool.getCold(handle2));

    var handle3 = try pool.put(5, 6);

    try std.testing.expectEqual(@as(usize, 0), pool.free_list.items.len);
    try std.testing.expectEqual(@as(usize, handle1.index), handle3.index);
}
