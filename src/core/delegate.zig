const std = @import("std");

pub fn delegate(comptime S: type, allocator: std.mem.Allocator) Delegate(S) {
    return Delegate(S).init(allocator);
}

pub fn Delegate(S: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        callbacks: std.ArrayListUnmanaged(S),

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .callbacks = std.ArrayListUnmanaged.init(allocator, S),
            };
        }

        pub fn connect(self: *Self, callback: S) std.mem.Allocator.Error!void {
            try self.callbacks.append(self.allocator, callback);
        }

        pub fn disconnect(self: *Self, callback: S) std.mem.Allocator.Error!void {
            if (std.mem.indexOfScalar(
                S,
                self.callbacks.items,
                callback,
            )) |found| {
                self.callbacks.swapRemove(found);
            }
        }

        pub fn broadcast(self: *Self, args: std.meta.ArgsTuple(S)) void {
            for (self.callbacks.items) |callback| {
                @call(.auto, callback, args);
            }
        }
    };
}
