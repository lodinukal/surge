const std = @import("std");

pub fn Channel(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const QueueType = std.atomic.Queue(T);
        pub const SenderType = Sender(T);
        pub const ReceiverType = Receiver(T);

        arena: std.heap.ArenaAllocator,
        allocator: std.mem.Allocator,
        queue: QueueType,
        connected: bool,

        pub fn init(allocator: std.mem.Allocator) Self {
            var arena = std.heap.ArenaAllocator.init(allocator);
            return Self{
                .arena = arena,
                .allocator = arena.allocator(),
                .queue = QueueType.init(),
                .connected = true,
            };
        }

        pub fn deinit(self: *Self) void {
            self.connected = false;
            _ = self.arena.reset(.retain_capacity);
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
                } else {
                    self.channel.arena.reset(.retain_capacity);
                }
            } else {
                return null;
            }
        }
    };
}
