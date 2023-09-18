const std = @import("std");

const platform = @import("../platform.zig");
const common = @import("../../core/common.zig");

pub const PlatformUserId = struct {
    internal_id: i32,
    pub const none = PlatformUserId{ .internal_id = -1 };

    pub inline fn get_internal_id(self: PlatformUserId) i32 {
        return self.internal_id;
    }

    pub inline fn init(internal_id: i32) PlatformUserId {
        return PlatformUserId{ .internal_id = internal_id };
    }

    pub inline fn is_valid(self: PlatformUserId) bool {
        return self.internal_id != none.internal_id;
    }

    pub inline fn eql(self: PlatformUserId, other: PlatformUserId) bool {
        return self.internal_id == other.internal_id;
    }

    pub inline fn hash(self: PlatformUserId) u32 {
        return @bitCast(self.internal_id);
    }
};

pub const InputDeviceId = struct {
    internal_id: i32,
    pub const none = InputDeviceId{ .internal_id = -1 };

    pub fn init(internal_id: i32) InputDeviceId {
        return InputDeviceId{ .internal_id = internal_id };
    }

    pub fn getId(self: InputDeviceId) i32 {
        return self.internal_id;
    }

    pub fn isValid(self: InputDeviceId) bool {
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

pub const InputDeviceConnectionState = enum(u8) {
    invalid,
    unknown,
    disconnected,
    connected,
};

pub const PlatformInputDeviceState = struct {
    owning_platform_user: PlatformUserId = null,
    connection_state: InputDeviceConnectionState = InputDeviceConnectionState.invalid,
};

pub const PlatformInputDeviceMapper = struct {
    const Self = @This();
    virtual: struct {
        deinit: ?fn (self: *Self) void = null,
        iterate_all_input_devices_for_user: ?fn (self: *const Self, user: PlatformUserId) AllInputDeviceForUserIterator = null,
        iterate_all_input_devices: ?fn (self: *const Self) AllInputDeviceIterator = null,
        iterate_all_connected_input_devices: ?fn (self: *const Self) AllInputDeviceConnectedIterator = null,
        iterate_all_active_users: ?fn (self: *const Self) ActiveUserIterator = null,
        get_user_for_unpaired_input_devices: ?fn (
            self: *const Self,
        ) PlatformUserId = null,
        is_unpaired_user_id: ?fn (
            self: *const Self,
            platform_id: PlatformUserId,
        ) bool = null,
        is_input_device_mapped_to_unpaired_user: ?fn (
            self: *const Self,
            input_device: InputDeviceId,
        ) bool = null,
        get_primary_platform_user: ?fn (self: *const Self) PlatformUserId = null,
        get_default_input_device: ?fn (self: *const Self) InputDeviceId = null,
        get_user_for_input_device: ?fn (
            self: *const Self,
            device_id: InputDeviceId,
        ) PlatformUserId = null,
        get_primary_input_device_for_user: ?fn (
            self: *const Self,
            user_id: PlatformUserId,
        ) InputDeviceId = null,
        internal_set_input_device_connection_state: ?fn (
            self: *Self,
            device_id: InputDeviceId,
            new_state: InputDeviceConnectionState,
        ) bool = null,
        get_input_device_connection_state: ?fn (
            self: *const Self,
            device_id: InputDeviceId,
        ) InputDeviceConnectionState = null,
        internal_map_input_device_to_user: ?fn (
            self: *Self,
            device_id: InputDeviceId,
            user_id: PlatformUserId,
            connection_state: InputDeviceConnectionState,
        ) bool = null,
        internal_change_input_device_user_mapping: ?fn (
            self: *Self,
            device_id: InputDeviceId,
            new_user_id: PlatformUserId,
            old_user_id: PlatformUserId,
        ) bool = null,
        allocate_new_user_id: ?fn (self: *Self) std.mem.Allocator.Error!PlatformUserId = null,
        allocate_new_input_device_id: ?fn (self: *Self) std.mem.Allocator.Error!InputDeviceId = null,
        _bind_core_delegates: ?fn (self: *Self) void = null,
        _unbind_core_delegates: ?fn (self: *Self) void = null,
        _on_user_login_changed_event: ?fn (
            self: *Self,
            user_id: PlatformUserId,
            is_logged_in: bool,
        ) void = null,
    },

    mapped_input_devices: std.AutoHashMap(InputDeviceId, PlatformInputDeviceState),
    last_platform_user_id: PlatformUserId = PlatformUserId.none,
    last_input_device_id: InputDeviceId = InputDeviceId.none,

    var on_user_input_device_connection_change: ?OnUserInputDeviceConnectionChange = null;
    var on_user_input_device_pairing_change: ?OnUserInputDevicePairingChange = null;

    pub fn get() *PlatformInputDeviceMapper {
        const Static = struct {
            var mapper: ?*PlatformInputDeviceMapper = null;
            var low_mapper: ?GenericPlatformInputDeviceMapper = null;
        };
        if (Static.mapper) |mapper| {
            return mapper;
        }
        Static.low_mapper = GenericPlatformInputDeviceMapper.init();
        Static.mapper = Static.low_mapper.?.interface();
        return Static.mapper.?;
    }

    pub fn init(allocator: std.mem.Allocator) PlatformInputDeviceMapper {
        var self = PlatformInputDeviceMapper{
            .mapped_input_devices = std.AutoHashMap(InputDeviceId, PlatformInputDeviceState).init(allocator),
        };
        self._bind_core_delegates();
        if (on_user_input_device_connection_change == null) {
            self.on_user_input_device_connection_change = OnUserInputDeviceConnectionChange.init(allocator);
        }
        if (on_user_input_device_pairing_change == null) {
            self.on_user_input_device_pairing_change = OnUserInputDevicePairingChange.init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *PlatformInputDeviceMapper) void {
        if (self.virtual.deinit) |f| return f(self);
        self._unbind_core_delegates();
        self.mapped_input_devices.deinit();
    }

    pub fn iterateAllInputDevicesForUser(
        self: *const PlatformInputDeviceMapper,
        user_id: PlatformUserId,
    ) AllInputDeviceForUserIterator {
        if (self.virtual.iterate_all_input_devices_for_user) |f| {
            return f(self);
        }
        return AllInputDeviceForUserIterator{
            ._it = self.mapped_input_devices.iterator(),
            ._user = user_id,
        };
    }

    const AllInputDeviceForUserIterator = struct {
        _it: std.AutoHashMap(InputDeviceId, PlatformInputDeviceState).Iterator,
        _user: PlatformUserId,

        pub fn next(self: *AllInputDeviceForUserIterator) ?InputDeviceId {
            var done = false;
            while (!done) {
                if (self._it.next()) |kv| {
                    if (kv.value_ptr.owning_platform_user == self._user) {
                        return kv.key_ptr.*;
                    }
                } else done = true;
            }
            return null;
        }
    };

    pub fn iterateAllInputDevices(self: *const PlatformInputDeviceMapper) AllInputDeviceIterator {
        if (self.virtual.iterate_all_input_devices) |f| {
            return f(self);
        }
        return AllInputDeviceIterator{
            ._it = self.mapped_input_devices.keyIterator(),
        };
    }

    const AllInputDeviceIterator = struct {
        _it: std.AutoHashMap(InputDeviceId, PlatformInputDeviceState).KeyIterator,

        pub fn next(self: *AllInputDeviceIterator) ?InputDeviceId {
            return (self._it.next() orelse return null).*;
        }
    };

    pub fn iterateAllConnectedInputDevices(self: *const PlatformInputDeviceMapper) AllInputDeviceConnectedIterator {
        if (self.virtual.iterate_all_connected_input_devices) |f| {
            return f(self);
        }
        return AllInputDeviceConnectedIterator{
            ._it = self.mapped_input_devices.iterator(),
        };
    }

    const AllInputDeviceConnectedIterator = struct {
        _it: std.AutoHashMap(InputDeviceId, PlatformInputDeviceState).Iterator,

        pub fn next(self: *AllInputDeviceConnectedIterator) ?InputDeviceId {
            var done = false;
            while (!done) {
                if (self._it.next()) |kv| {
                    if (kv.value_ptr.connection_state == InputDeviceConnectionState.connected) {
                        return kv.key_ptr.*;
                    }
                } else done = true;
            }
            return null;
        }
    };

    pub fn iterateAllActiveUsers(self: *const PlatformInputDeviceMapper) ActiveUserIterator {
        if (self.virtual.iterate_all_active_users) |f| {
            return f(self);
        }
        return ActiveUserIterator{
            ._it = self.mapped_input_devices.iterator(),
        };
    }

    const ActiveUserIterator = struct {
        _it: std.AutoHashMap(InputDeviceId, PlatformInputDeviceState).Iterator,

        pub fn next(self: *ActiveUserIterator) ?PlatformUserId {
            var done = false;
            while (!done) {
                if (self._it.next()) |kv| {
                    if (kv.value_ptr.owning_platform_user) |user| {
                        return user.*;
                    }
                } else done = true;
            }
            return null;
        }
    };

    pub fn getUserForUnpairedInputDevices(
        self: *const PlatformInputDeviceMapper,
    ) PlatformUserId {
        if (self.virtual.get_user_for_unpaired_input_devices) |f| {
            return f(self);
        }
        unreachable;
    }

    pub fn isUnpairedUserId(
        self: *const PlatformInputDeviceMapper,
        platform_id: PlatformUserId,
    ) bool {
        if (self.virtual.is_unpaired_user_id) |f| {
            return f(self, platform_id);
        }
        return platform_id == self.get_user_for_unpaired_input_devices();
    }

    pub fn isInputDeviceMappedToUnpairedUser(
        self: *const PlatformInputDeviceMapper,
        input_device: InputDeviceId,
    ) bool {
        if (self.virtual.is_input_device_mapped_to_unpaired_user) |f| {
            return f(self, input_device);
        }
        if (self.mapped_input_devices.get(input_device)) |device_state| {
            return self.is_unpaired_user_id(device_state.owning_platform_user);
        }
        return false;
    }

    pub fn getPrimaryPlatformUser(self: *const PlatformInputDeviceMapper) PlatformUserId {
        if (self.virtual.get_primary_platform_user) |f| {
            return f(self);
        }
        unreachable;
    }

    pub fn getDefaultInputDevice(self: *const PlatformInputDeviceMapper) InputDeviceId {
        if (self.virtual.get_default_input_device) |f| {
            return f(self);
        }
        unreachable;
    }

    pub fn getUserForInputDevice(
        self: *const PlatformInputDeviceMapper,
        device_id: InputDeviceId,
    ) PlatformUserId {
        if (self.virtual.get_user_for_input_device) |f| {
            return f(self, device_id);
        }
        if (self.mapped_input_devices.get(device_id)) |device_state| {
            return device_state.owning_platform_user;
        }
        return PlatformUserId.none;
    }

    pub fn getPrimaryInputDeviceForUser(
        self: *const PlatformInputDeviceMapper,
        user_id: PlatformUserId,
    ) InputDeviceId {
        if (self.virtual.get_primary_input_device_for_user) |f| {
            return f(self, user_id);
        }
        var found: InputDeviceId = InputDeviceId.none;
        var it = self.mapped_input_devices.iterator();
        while (it.next()) |kv| {
            if (kv.value_ptr.owning_platform_user == user_id) {
                if (!found.is_valid() or found.?.order(kv.key_ptr) == .gt) {
                    found = kv.key_ptr.*;
                }
            }
        }
        return found;
    }

    pub fn internalSetInputDeviceConnectionState(
        self: *PlatformInputDeviceMapper,
        device_id: InputDeviceId,
        new_state: InputDeviceConnectionState,
    ) bool {
        if (self.virtual.internal_set_input_device_connection_state) |f| {
            return f(self, device_id, new_state);
        }
        if (!device_id.is_valid()) {
            //TODO(logging): internal_set_input_device_connection_state called with invalid device_id
            return false;
        }

        if (self.get_input_device_connection_state(device_id) == new_state) {
            return false;
        }

        var owning_user = self.get_user_for_input_device(device_id);
        if (!owning_user.is_valid()) {
            owning_user = self.get_user_for_unpaired_input_devices();
        }

        return self.internal_map_input_device_to_user(device_id, owning_user, new_state);
    }

    pub fn getInputDeviceConnectionState(
        self: *const PlatformInputDeviceMapper,
        device_id: InputDeviceId,
    ) InputDeviceConnectionState {
        if (self.virtual.get_input_device_connection_state) |f| {
            return f(self, device_id);
        }
        var state = InputDeviceConnectionState.unknown;

        if (!device_id.is_valid()) {
            state = .invalid;
        } else if (self.mapped_input_devices.get(device_id)) |device_state| {
            state = device_state.connection_state;
        }

        return state;
    }

    pub fn internalMapInputDeviceToUser(
        self: *PlatformInputDeviceMapper,
        device_id: InputDeviceId,
        user_id: PlatformUserId,
        connection_state: InputDeviceConnectionState,
    ) bool {
        if (self.virtual.internal_map_input_device_to_user) |f| {
            return f(self, device_id, user_id, connection_state);
        }
        if (!device_id.is_valid()) {
            //TODO(logging): internal_map_input_device_to_user called with invalid device_id
            return false;
        }

        {
            if (device_id.order(self.last_input_device_id) == .gt) {
                self.last_input_device_id = device_id;
            }

            if (user_id.order(self.last_platform_user_id) == .gt) {
                self.last_platform_user_id = user_id;
            }
        }

        const input_device_state = self.mapped_input_devices.getOrPut(device_id) catch return false;
        input_device_state.value_ptr.*.owning_platform_user = user_id;
        input_device_state.value_ptr.*.connection_state = connection_state;

        self.on_user_input_device_connection_change.?.broadcast(.{ connection_state, user_id, device_id });

        return true;
    }

    pub fn internalChangeInputDeviceUserMapping(
        self: *PlatformInputDeviceMapper,
        device_id: InputDeviceId,
        new_user_id: PlatformUserId,
        old_user_id: PlatformUserId,
    ) bool {
        if (self.virtual.internal_change_input_device_user_mapping) |f| {
            return f(self, device_id, new_user_id, old_user_id);
        }
        if (!device_id.is_valid()) {
            //TODO(logging): internal_change_input_device_user_mapping called with invalid device_id
            return false;
        }

        if (self.mapped_input_devices.get(device_id)) |device_state| {
            if (device_state.owning_platform_user == old_user_id) {
                device_state.owning_platform_user = new_user_id;
            }
        } else {
            //TODO(logging): internal_change_input_device_user_mapping device_id is not mapped to any user
            return false;
        }

        self.on_user_input_device_pairing_change.?.broadcast(.{ device_id, new_user_id, old_user_id });

        return true;
    }

    pub const OnUserInputDeviceConnectionChange = common.Delegate(fn (
        new_connection_state: InputDeviceConnectionState,
        platform_user_id: PlatformUserId,
        input_device_id: InputDeviceId,
    ) void);

    pub const OnUserInputDevicePairingChange = common.Delegate(fn (
        input_device_id: InputDeviceId,
        new_user_id: PlatformUserId,
        old_user_id: PlatformUserId,
    ) void);

    pub fn getOnUserInputDeviceConnectionChange(
        self: *const PlatformInputDeviceMapper,
    ) *?OnUserInputDeviceConnectionChange {
        return &self.on_user_input_device_connection_change;
    }

    pub fn getOnUserInputDevicePairingChange(
        self: *const PlatformInputDeviceMapper,
    ) *?OnUserInputDevicePairingChange {
        return &self.on_user_input_device_pairing_change;
    }

    pub fn allocateNewUserId(self: *PlatformInputDeviceMapper) std.mem.Allocator.Error!PlatformUserId {
        if (self.virtual.allocate_new_user_id) |f| {
            return f(self);
        }
        unreachable;
    }

    pub fn allocateNewInputDeviceId(self: *PlatformInputDeviceMapper) std.mem.Allocator.Error!InputDeviceId {
        if (self.virtual.allocate_new_input_device_id) |f| {
            return f(self);
        }
        unreachable;
    }

    pub fn BindCoreDelegates(self: *PlatformInputDeviceMapper) void {
        if (self.virtual._bind_core_delegates) |f| {
            return f(self);
        }
        //TODO: bind core delegates
    }

    pub fn UnbindCoreDelegates(self: *PlatformInputDeviceMapper) void {
        if (self.virtual._unbind_core_delegates) |f| {
            return f(self);
        }
        //TODO: unbind core delegates
    }

    pub fn OnUserLoginChangedEvent(
        self: *PlatformInputDeviceMapper,
        user_id: PlatformUserId,
        is_logged_in: bool,
    ) void {
        if (self.virtual._on_user_login_changed_event) |f| {
            return f(self, user_id, is_logged_in);
        }
        unreachable;
    }
};

pub const GenericPlatformInputDeviceMapper = struct {
    const Self = @This();
    root: PlatformInputDeviceMapper = undefined,

    pub fn init(allocator: std.mem.Allocator) GenericPlatformInputDeviceMapper {
        var self = GenericPlatformInputDeviceMapper{
            .root = PlatformInputDeviceMapper.init(allocator),
        };
        self.root.virtual.get_user_for_unpaired_input_devices = struct {
            pub fn func(this: *const PlatformInputDeviceMapper) PlatformUserId {
                return common.getRoot(this).get_user_for_unpaired_input_devices();
            }
        }.func;
        self.root.virtual.get_primary_platform_user = struct {
            pub fn func(this: *const PlatformInputDeviceMapper) PlatformUserId {
                return common.getRoot(this).get_primary_platform_user();
            }
        }.func;
        self.root.virtual.get_default_input_device = struct {
            pub fn func(this: *const PlatformInputDeviceMapper) InputDeviceId {
                return common.getRoot(this).get_default_input_device();
            }
        }.func;
        self.root.virtual._on_user_login_changed_event = struct {
            pub fn func(this: *PlatformInputDeviceMapper, user_id: PlatformUserId, is_logged_in: bool) void {
                return common.getRoot(this).on_user_login_changed_event(user_id, is_logged_in);
            }
        }.func;
        self.root.virtual.allocate_new_user_id = struct {
            pub fn func(this: *PlatformInputDeviceMapper) std.mem.Allocator.Error!PlatformUserId {
                return common.getRoot(this).allocate_new_user_id();
            }
        }.func;
        self.root.virtual.allocate_new_input_device_id = struct {
            pub fn func(this: *PlatformInputDeviceMapper) std.mem.Allocator.Error!InputDeviceId {
                return common.getRoot(this).allocate_new_input_device_id();
            }
        }.func;
        self.root.last_input_device_id = self.get_default_input_device();
        self.root.last_platform_user_id = self.get_primary_platform_user();

        return self;
    }

    pub fn getUserForUnpairedInputDevices(
        self: *const GenericPlatformInputDeviceMapper,
    ) PlatformUserId {
        _ = self;
        return PlatformUserId.none;
    }

    pub fn getPrimaryPlatformUser(self: *const GenericPlatformInputDeviceMapper) PlatformUserId {
        _ = self;
        return PlatformUserId.init(0);
    }

    pub fn getDefaultInputDevice(self: *const GenericPlatformInputDeviceMapper) InputDeviceId {
        _ = self;
        return InputDeviceId.init(0);
    }

    pub fn onUserLoginChangedEvent(
        self: *GenericPlatformInputDeviceMapper,
        user_id: PlatformUserId,
        is_logged_in: bool,
    ) void {
        if (is_logged_in) {} else {
            const unknown_user_id = self.root.get_user_for_unpaired_input_devices();
            if (!unknown_user_id.eql(user_id)) {
                var it = self.root.iterate_all_input_devices_for_user(user_id);
                while (it.next()) |device_id| {
                    self.root.internal_change_input_device_user_mapping(
                        device_id,
                        unknown_user_id,
                        user_id,
                    );
                }
            }
        }
    }

    pub fn allocateNewUserId(self: *GenericPlatformInputDeviceMapper) std.mem.Allocator.Error!PlatformUserId {
        return PlatformUserId.init(self.root.last_platform_user_id.get_internal_id() + 1);
    }

    pub fn allocateNewInputDeviceId(self: *GenericPlatformInputDeviceMapper) std.mem.Allocator.Error!InputDeviceId {
        return InputDeviceId.init(self.root.last_input_device_id.get_id() + 1);
    }
};

test {
    std.testing.refAllDecls(@This());
}
