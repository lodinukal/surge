const std = @import("std");

const PlatformUserId = struct {
    internal_id: i32,
    const none = PlatformUserId{ .internal_id = -1 };

    pub inline fn is_valid(self: PlatformUserId) bool {
        return self.eql(PlatformUserId.none) == false;
    }

    pub inline fn get_internal_id(self: PlatformUserId) i32 {
        return self.internal_id;
    }

    pub inline fn init(internal_id: i32) PlatformUserId {
        return PlatformUserId{ .internal_id = internal_id };
    }

    pub inline fn eql(self: PlatformUserId, other: PlatformUserId) bool {
        return self.internal_id == other.internal_id;
    }

    pub inline fn hash(self: PlatformUserId) u32 {
        return @bitCast(self.internal_id);
    }
};

const InputDeviceId = struct {
    internal_id: i32,
    const none = InputDeviceId{ .internal_id = -1 };

    pub fn init(internal_id: i32) InputDeviceId {
        return InputDeviceId{ .internal_id = internal_id };
    }

    pub fn get_id(self: InputDeviceId) i32 {
        return self.internal_id;
    }

    pub fn is_valid(self: InputDeviceId) bool {
        return self.internal_id >= 0;
    }

    pub fn eql(self: InputDeviceId, other: InputDeviceId) bool {
        return self.internal_id == other.internal_id;
    }

    pub fn order(self: InputDeviceId, other: InputDeviceId) std.math.Order {
        return std.math.order(self.internal_id, other.internal_id);
    }

    pub fn hash(self: InputDeviceId) u32 {
        return @bitCast(self.internal_id);
    }
};

const InputDeviceConnectionState = enum(u8) {
    invalid,
    unknown,
    disconnected,
    connected,
};

const PlatformInputDeviceState = struct {
    owning_platform_user: PlatformUserId = PlatformUserId.none,
    connection_state: InputDeviceConnectionState = InputDeviceConnectionState.invalid,
};

const PlatformInputDeviceMapper = struct {
    const Self = @This();
    const Virtual = struct {
        const deinit: ?fn (self: *Self) void = null;
        const get_all_input_devices_for_user: ?fn (
            self: Self,
            user_id: PlatformUserId,
            out_devices: *std.ArrayList(InputDeviceId),
        ) i32 = null;
        const get_all_input_devices: ?fn (
            self: Self,
            out_devices: *std.ArrayList(InputDeviceId),
        ) i32 = null;
        const get_all_connected_input_devices: ?fn (
            self: Self,
            out_devices: *std.ArrayList(InputDeviceId),
        ) i32 = null;
        const get_all_active_users: ?fn (
            self: Self,
            out_users: *std.ArrayList(PlatformUserId),
        ) i32 = null;
        const get_user_for_unpaired_input_devices: ?fn (
            self: Self,
        ) i32 = null;
    };

    pub fn get() *PlatformInputDeviceMapper {
        return 0;
    }

    pub fn init() void {}

    pub fn deinit(self: *PlatformInputDeviceMapper) void {
        if (Self.Virtual.deinit) |f| f(self);
        unreachable;
    }

    pub fn get_all_input_devices_for_user(
        self: PlatformInputDeviceMapper,
        user_id: PlatformUserId,
        out_devices: *std.ArrayList(InputDeviceId),
    ) i32 {
        if (Self.Virtual.get_all_input_devices_for_user) |f| {
            return f(self, user_id, out_devices);
        }
        unreachable;
    }

    pub fn get_all_input_devices(
        self: PlatformInputDeviceMapper,
        out_devices: *std.ArrayList(InputDeviceId),
    ) i32 {
        if (Self.Virtual.get_all_input_devices) |f| {
            return f(self, out_devices);
        }
        unreachable;
    }

    pub fn get_all_connected_input_devices(
        self: PlatformInputDeviceMapper,
        out_devices: *std.ArrayList(InputDeviceId),
    ) i32 {
        if (Self.Virtual.get_all_connected_input_devices) |f| {
            return f(self, out_devices);
        }
        unreachable;
    }

    pub fn get_all_active_users(
        self: PlatformInputDeviceMapper,
        out_users: *std.ArrayList(PlatformUserId),
    ) i32 {
        if (Self.Virtual.get_all_active_users) |f| {
            return f(self, out_users);
        }
        unreachable;
    }

    pub fn get_user_for_unpaired_input_devices(
        self: PlatformInputDeviceMapper,
        out_user: *PlatformUserId,
    ) i32 {
        if (Self.Virtual.get_user_for_unpaired_input_devices) |f| {
            return f(self, out_user);
        }
        unreachable;
    }
};
