const std = @import("std");

pub fn Channel(comptime T: type) type {
    return struct {
        const Self = @This();
        const QueueType = std.atomic.Queue(T);

        allocator: std.mem.Allocator,
        queue: QueueType,
        connected: bool,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .queue = QueueType.init(),
                .connected = true,
            };
        }

        pub fn getSender(c: *Self) Sender(T) {
            return Sender(T).init(c);
        }

        pub fn getReceiver(c: *Self) Receiver(T) {
            return Receiver(T).init(c);
        }
    };
}

pub fn Sender(comptime T: type) type {
    return struct {
        const Self = @This();
        const ChannelType = Channel(T);

        channel: *ChannelType,

        pub fn init(channel: *ChannelType) Self {
            return Self{
                .channel = channel,
            };
        }

        pub fn send(self: *Self, value: T) !void {
            if (self.channel.connected) {
                var node = try self.channel.allocator.create(ChannelType.QueueType.Node);
                node.* = .{
                    .prev = undefined,
                    .next = undefined,
                    .data = value,
                };
                self.channel.queue.put(node);
            }
        }
    };
}

pub fn Receiver(comptime T: type) type {
    return struct {
        const Self = @This();
        const ChannelType = Channel(T);

        channel: *ChannelType,

        pub fn init(channel: *ChannelType) Self {
            return Self{
                .channel = channel,
            };
        }

        pub fn receive(self: *Self) !?T {
            if (self.channel.connected) {
                if (self.channel.queue.get()) |node| {
                    defer {
                        self.channel.queue.remove(node);
                        self.channel.allocator.destroy(node);
                    }
                    return node.data;
                }
            } else {
                return null;
            }
        }
    };
}
