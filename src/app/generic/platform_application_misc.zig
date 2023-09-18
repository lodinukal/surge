const std = @import("std");

const input_device_mapper = @import("input_device_mapper.zig");

pub const ScreenPhysicalAccuracy = enum {
    unknown,
    approximation,
    truth,
};

pub const ShowInputDeviceSelectorParams = struct {
    input_device_id: input_device_mapper.InputDeviceId,
    platform_user_id: input_device_mapper.PlatformUserId,
};
pub const ShowInputDeviceSelectorComplete = fn (*const ShowInputDeviceSelectorParams) void;

pub const PlatformUserSelectionCompleteParams = struct {
    selected_user_id: input_device_mapper.PlatformUserId,
    success: bool,
};
pub const PlatformUserSelectionComplete = fn (*const PlatformUserSelectionCompleteParams) void;

pub const PlatformUserSelectorFlags = packed struct {
    requires_online_enabled_profile: bool = false,
    show_skip_button: bool = true,
    allow_guests: bool = false,
    show_new_users_only: bool = false,
};

pub const GenericPlatformApplicationMisc = struct {
    pub fn pre_init() void {}

    pub fn init() void {}

    pub fn post_init() void {}

    pub fn teardown() void {}

    pub fn load_pre_init_modules() void {}

    pub fn load_startup_modules() void {}

    // pub fn create_console_output_device() *OutputDeviceConsole {}

    // pub fn get_error_output_device() *OutputDeviceError {}

    // pub fn get_feedback_context() * FeedbackContext {}

    pub fn get_platform_input_device_manager(
        allocator: std.mem.Allocator,
    ) *input_device_mapper.PlatformInputDeviceMapper {
        return input_device_mapper.PlatformInputDeviceMapper.init(allocator);
    }

    // pub fn create_application() *GenericApplication {}

    pub fn request_minimise() void {}

    pub fn is_this_application_foreground() bool {}

    pub fn requires_virtual_keyboard() bool {}

    pub inline fn pump_messages(from_main_loop: bool) void {
        _ = from_main_loop;
    }

    pub fn prevent_screen_saver() void {}

    const ScreenSaverAction = enum {
        disable,
        enable,
    };

    pub fn is_screensaver_enabled() bool {
        return false;
    }

    pub fn control_screensaver(action: ScreenSaverAction) bool {
        _ = action;
        return false;
    }
};
