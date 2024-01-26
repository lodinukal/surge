const std = @import("std");

pub fn Delegate(comptime S: type, comptime blocks: bool) type {
    return struct {
        pub const Delegate = DelegateHolder(S, blocks);
        pub const Node = DelegateNode(S);
    };
}

pub fn DelegateNode(comptime S: type) type {
    return struct {
        const Self = @This();
        callback: *const S,
        previous: ?*Self = null,
        next: ?*Self = null,

        pub inline fn init(callback: anytype) Self {
            return Self{
                .callback = callback,
            };
        }

        pub inline fn disconnect(self: *Self) void {
            if (self.previous) |previous| {
                previous.next = self.next;
            }
            if (self.next) |next| {
                next.previous = self.previous;
            }
        }
    };
}

pub fn DelegateHolder(comptime S: type, comptime blocks: bool) type {
    return struct {
        const Self = @This();
        const Node = DelegateNode(S);
        callback_list: ?*Node = null,

        pub fn init() Self {
            return Self{};
        }

        pub fn connect(self: *Self, callback: *Node) void {
            if (self.callback_list) |cbl| {
                cbl.next = callback;
                callback.previous = cbl;
            } else {
                self.callback_list = callback;
            }
        }

        pub fn broadcast(self: *Self, args: std.meta.ArgsTuple(S)) void {
            var item = self.callback_list;
            while (item) |i| {
                const s = i.callback;
                if (blocks) {
                    if (@call(.auto, s, args)) return;
                } else {
                    @call(.auto, s, args);
                }
                item = i.next;
            }
        }
    };
}
