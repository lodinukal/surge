const std = @import("std");

const platform = @import("../platform.zig");
const common = @import("../../core/common.zig");
const interface = @import("../../core/interface.zig");

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
    pub const Virtual = interface.VirtualTable(struct {
        deinit: fn (self: *Self) void,
        iterateAllInputDevicesForUser: fn (self: *const Self, user: PlatformUserId) AllInputDeviceForUserIterator,
        iterateAllInputDevices: fn (self: *const Self) AllInputDeviceIterator,
        iterateAllConnectedInputDevices: fn (self: *const Self) AllInputDeviceConnectedIterator,
        iterateAllActiveUsers: fn (self: *const Self) ActiveUserIterator,
        getUserForUnpairedInputDevices: fn (
            self: *const Self,
        ) PlatformUserId,
        isUnpairedUserId: fn (
            self: *const Self,
            platform_id: PlatformUserId,
        ) bool,
        isInputDeviceMappedToUnpairedUser: fn (
            self: *const Self,
            input_device: InputDeviceId,
        ) bool,
        getPrimaryPlatformUser: fn (self: *const Self) PlatformUserId,
        getDefaultInputDevice: fn (self: *const Self) InputDeviceId,
        getUserForInputDevice: fn (
            self: *const Self,
            device_id: InputDeviceId,
        ) PlatformUserId,
        getPrimaryInputDeviceForUser: fn (
            self: *const Self,
            user_id: PlatformUserId,
        ) InputDeviceId,
        internalSetInputDeviceConnectionState: fn (
            self: *Self,
            device_id: InputDeviceId,
            new_state: InputDeviceConnectionState,
        ) bool,
        getInputDeviceConnectionState: fn (
            self: *const Self,
            device_id: InputDeviceId,
        ) InputDeviceConnectionState,
        internalMapInputDeviceToUser: fn (
            self: *Self,
            device_id: InputDeviceId,
            user_id: PlatformUserId,
            connection_state: InputDeviceConnectionState,
        ) bool,
        internalChangeInputDeviceUserMapping: fn (
            self: *Self,
            device_id: InputDeviceId,
            new_user_id: PlatformUserId,
            old_user_id: PlatformUserId,
        ) bool,
        allocateNewUserId: fn (self: *Self) std.mem.Allocator.Error!PlatformUserId,
        allocateNewInputDeviceId: fn (self: *Self) std.mem.Allocator.Error!InputDeviceId,
        BindCoreDelegates: fn (self: *Self) void,
        UnbindCoreDelegates: fn (self: *Self) void,
        OnUserLoginChangedEvent: fn (
            self: *Self,
            user_id: PlatformUserId,
            is_logged_in: bool,
        ) void,
    });
    virtual: ?*const Virtual = null,

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
        self.BindCoreDelegates();
        if (on_user_input_device_connection_change == null) {
            self.on_user_input_device_connection_change = OnUserInputDeviceConnectionChange.init(allocator);
        }
        if (on_user_input_device_pairing_change == null) {
            self.on_user_input_device_pairing_change = OnUserInputDevicePairingChange.init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *PlatformInputDeviceMapper) void {
        if (self.virtual) |v| if (v.deinit) |f| return f(self);
        self.UnbindCoreDelegates();
        self.mapped_input_devices.deinit();
    }

    pub fn iterateAllInputDevicesForUser(
        self: *const PlatformInputDeviceMapper,
        user_id: PlatformUserId,
    ) AllInputDeviceForUserIterator {
        if (self.virtual) |v| if (v.iterateAllInputDevicesForUser) |f| {
            return f(self);
        };
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
        if (self.virtual) |v| if (v.iterateAllInputDevices) |f| {
            return f(self);
        };
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
        if (self.virtual) |v| if (v.iterateAllConnectedInputDevices) |f| {
            return f(self);
        };
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
        if (self.virtual) |v| if (v.iterateAllActiveUsers) |f| {
            return f(self);
        };
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
        if (self.virtual) |v| if (v.getUserForUnpairedInputDevices) |f| {
            return f(self);
        };
        unreachable;
    }

    pub fn isUnpairedUserId(
        self: *const PlatformInputDeviceMapper,
        platform_id: PlatformUserId,
    ) bool {
        if (self.virtual) |v| if (v.isUnpairedUserId) |f| {
            return f(self, platform_id);
        };
        return platform_id == self.getUserForUnpairedInputDevices();
    }

    pub fn isInputDeviceMappedToUnpairedUser(
        self: *const PlatformInputDeviceMapper,
        input_device: InputDeviceId,
    ) bool {
        if (self.virtual) |v| if (v.isInputDeviceMappedToUnpairedUser) |f| {
            return f(self, input_device);
        };
        if (self.mapped_input_devices.get(input_device)) |device_state| {
            return self.isUnpairedUserId(device_state.owning_platform_user);
        }
        return false;
    }

    pub fn getPrimaryPlatformUser(self: *const PlatformInputDeviceMapper) PlatformUserId {
        if (self.virtual) |v| if (v.getPrimaryPlatformUser) |f| {
            return f(self);
        };
        unreachable;
    }

    pub fn getDefaultInputDevice(self: *const PlatformInputDeviceMapper) InputDeviceId {
        if (self.virtual) |v| if (v.getDefaultInputDevice) |f| {
            return f(self);
        };
        unreachable;
    }

    pub fn getUserForInputDevice(
        self: *const PlatformInputDeviceMapper,
        device_id: InputDeviceId,
    ) PlatformUserId {
        if (self.virtual) |v| if (v.getUserForInputDevice) |f| {
            return f(self, device_id);
        };
        if (self.mapped_input_devices.get(device_id)) |device_state| {
            return device_state.owning_platform_user;
        }
        return PlatformUserId.none;
    }

    pub fn getPrimaryInputDeviceForUser(
        self: *const PlatformInputDeviceMapper,
        user_id: PlatformUserId,
    ) InputDeviceId {
        if (self.virtual) |v| if (v.getPrimaryInputDeviceForUser) |f| {
            return f(self, user_id);
        };
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
        if (self.virtual) |v| if (v.internalSetInputDeviceConnectionState) |f| {
            return f(self, device_id, new_state);
        };
        if (!device_id.is_valid()) {
            //TODO(logging): internalSetInputDeviceConnectionState called with invalid device_id
            return false;
        }

        if (self.getInputDeviceConnectionState(device_id) == new_state) {
            return false;
        }

        var owning_user = self.getUserForInputDevice(device_id);
        if (!owning_user.is_valid()) {
            owning_user = self.getUserForUnpairedInputDevices();
        }

        return self.internalMapInputDeviceToUser(device_id, owning_user, new_state);
    }

    pub fn getInputDeviceConnectionState(
        self: *const PlatformInputDeviceMapper,
        device_id: InputDeviceId,
    ) InputDeviceConnectionState {
        if (self.virtual) |v| if (v.getInputDeviceConnectionState) |f| {
            return f(self, device_id);
        };
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
        if (self.virtual) |v| if (v.internalMapInputDeviceToUser) |f| {
            return f(self, device_id, user_id, connection_state);
        };
        if (!device_id.is_valid()) {
            //TODO(logging): internalMapInputDeviceToUser called with invalid device_id
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
        if (self.virtual) |v| if (v.internalChangeInputDeviceUserMapping) |f| {
            return f(self, device_id, new_user_id, old_user_id);
        };
        if (!device_id.is_valid()) {
            //TODO(logging): internalChangeInputDeviceUserMapping called with invalid device_id
            return false;
        }

        if (self.mapped_input_devices.get(device_id)) |device_state| {
            if (device_state.owning_platform_user == old_user_id) {
                device_state.owning_platform_user = new_user_id;
            }
        } else {
            //TODO(logging): internalChangeInputDeviceUserMapping device_id is not mapped to any user
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
        if (self.virtual) |v| if (v.allocateNewUserId) |f| {
            return f(self);
        };
        unreachable;
    }

    pub fn allocateNewInputDeviceId(self: *PlatformInputDeviceMapper) std.mem.Allocator.Error!InputDeviceId {
        if (self.virtual) |v| if (v.allocateNewInputDeviceId) |f| {
            return f(self);
        };
        unreachable;
    }

    pub fn BindCoreDelegates(self: *PlatformInputDeviceMapper) void {
        if (self.virtual) |v| if (v.BindCoreDelegates) |f| {
            return f(self);
        };
        //TODO: bind core delegates
    }

    pub fn UnbindCoreDelegates(self: *PlatformInputDeviceMapper) void {
        if (self.virtual) |v| if (v.UnbindCoreDelegates) |f| {
            return f(self);
        };
        //TODO: unbind core delegates
    }

    pub fn OnUserLoginChangedEvent(
        self: *PlatformInputDeviceMapper,
        user_id: PlatformUserId,
        is_logged_in: bool,
    ) void {
        if (self.virtual) |v| if (v.OnUserLoginChangedEvent) |f| {
            return f(self, user_id, is_logged_in);
        };
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
        self.root.virtual.getUserForUnpairedInputDevices = struct {
            pub fn func(this: *const PlatformInputDeviceMapper) PlatformUserId {
                return common.getRoot(this).getUserForUnpairedInputDevices();
            }
        }.func;
        self.root.virtual.getPrimaryPlatformUser = struct {
            pub fn func(this: *const PlatformInputDeviceMapper) PlatformUserId {
                return common.getRoot(this).getPrimaryPlatformUser();
            }
        }.func;
        self.root.virtual.getDefaultInputDevice = struct {
            pub fn func(this: *const PlatformInputDeviceMapper) InputDeviceId {
                return common.getRoot(this).getDefaultInputDevice();
            }
        }.func;
        self.root.virtual.OnUserLoginChangedEvent = struct {
            pub fn func(this: *PlatformInputDeviceMapper, user_id: PlatformUserId, is_logged_in: bool) void {
                return common.getRoot(this).on_user_login_changed_event(user_id, is_logged_in);
            }
        }.func;
        self.root.virtual.allocateNewUserId = struct {
            pub fn func(this: *PlatformInputDeviceMapper) std.mem.Allocator.Error!PlatformUserId {
                return common.getRoot(this).allocateNewUserId();
            }
        }.func;
        self.root.virtual.allocateNewInputDeviceId = struct {
            pub fn func(this: *PlatformInputDeviceMapper) std.mem.Allocator.Error!InputDeviceId {
                return common.getRoot(this).allocateNewInputDeviceId();
            }
        }.func;
        self.root.last_input_device_id = self.getDefaultInputDevice();
        self.root.last_platform_user_id = self.getPrimaryPlatformUser();

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
            const unknown_user_id = self.root.getUserForUnpairedInputDevices();
            if (!unknown_user_id.eql(user_id)) {
                var it = self.root.iterateAllInputDevicesForUser(user_id);
                while (it.next()) |device_id| {
                    self.root.internalChangeInputDeviceUserMapping(
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
