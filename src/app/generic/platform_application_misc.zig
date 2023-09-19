const std = @import("std");

const math = @import("../../core/math.zig");

const input_device_mapper = @import("input_device_mapper.zig");
const platform = @import("../platform.zig");

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
    const PlatformBind = platform.impl.PlatformApplicationMisc;

    pub var cached_physical_screen_data: bool = false;
    pub var cached_physical_screen_density: i32 = 0;
    pub var cached_physical_screen_accuracy: ScreenPhysicalAccuracy = .unknown;

    pub fn preInit() void {}

    pub fn init() void {}

    pub fn postInit() void {}

    pub fn teardown() void {}

    pub fn loadPreInitModules() void {}

    pub fn loadStartupModules() void {}

    // pub fn createConsoleOutputDevice() *OutputDeviceConsole {}

    // pub fn getErrorOutputDevice() *OutputDeviceError {}

    // pub fn getFeedbackContext() * FeedbackContext {}

    pub fn getPlatformInputDeviceManager(
        allocator: std.mem.Allocator,
    ) *input_device_mapper.PlatformInputDeviceMapper {
        return input_device_mapper.PlatformInputDeviceMapper.init(allocator);
    }

    // pub fn createApplication() *GenericApplication {}

    pub fn requestMinimise() void {}

    pub fn isThisApplicationForeground() bool {
        return false;
    }

    pub fn requiresVirtualKeyboard() bool {
        return false;
    }

    pub inline fn pumpMessages(from_main_loop: bool) void {
        _ = from_main_loop;
    }

    pub fn preventScreenSaver() void {}

    const ScreenSaverAction = enum {
        disable,
        enable,
    };

    pub fn isScreensaverEnabled() bool {
        return false;
    }

    pub fn controlScreensaver(action: ScreenSaverAction) bool {
        _ = action;
        return false;
    }

    pub fn getScreenPixelColour(x: i32, y: i32, in_gamma: ?f32) math.colour.LinearColour {
        _ = in_gamma;
        _ = y;
        _ = x;
        return math.colour.LinearColour.black;
    }

    pub fn setHighDpiMode() void {}

    pub fn getDpiScaleFactorAtPoint(x: f32, y: f32) f32 {
        _ = y;
        _ = x;
        return 1.0;
    }

    pub fn anchorWindowPositionTopLeft() bool {
        return false;
    }

    pub fn setGamepadsAllowed(allowed: bool) void {
        _ = allowed;
    }

    pub fn setGamepadsBlockDeviceFeedback(allowed: bool) void {
        _ = allowed;
    }

    pub fn resetGamepadAssignments() void {}

    pub fn resetGamepadAssignmentToController(id: input_device_mapper.InputDeviceId) void {
        _ = id;
    }

    pub fn isControllerAssignedToGamepad(id: input_device_mapper.InputDeviceId) bool {
        return id.get_id() == 0;
    }

    pub fn getGamepadControllerName(
        allocator: std.mem.Allocator,
        id: input_device_mapper.InputDeviceId,
    ) std.mem.Allocator.Error![]u8 {
        if (PlatformBind.isControllerAssignedToGamepad(id)) {
            return try allocator.dupe(u8, "generic");
        }
        return try allocator.dupe(u8, "none");
    }

    // glyph for gamepad, TODO: later

    pub fn enableMotionData(enable: bool) void {
        _ = enable;
    }

    pub fn isMotionDataEnabled() bool {
        return true;
    }

    pub fn clipboardCopy(text: []const u8) void {
        _ = text;
    }

    pub fn clipboardPaste(allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
        return try allocator.dupe(u8, "");
    }

    pub fn getPhysicalScreenDensity(out_screen_density: *i32) ScreenPhysicalAccuracy {
        if (!cached_physical_screen_data) {
            cached_physical_screen_data = true;
            cached_physical_screen_accuracy = PlatformBind.computePhysicalScreenDensity(
                &cached_physical_screen_density,
            );
            if (cached_physical_screen_accuracy == .unknown) {
                cached_physical_screen_density = 96;
            }
        }

        out_screen_density.* = cached_physical_screen_density;

        return cached_physical_screen_accuracy;
    }

    pub fn computePhysicalScreenDensity(out_screen_density: *i32) ScreenPhysicalAccuracy {
        out_screen_density.* = 0;
        return .unknown;
    }

    pub fn convertInchesToPixels(inches: f32, out_pixels: *f32) ScreenPhysicalAccuracy {
        var density: i32 = 0;
        var accuracy = PlatformBind.computePhysicalScreenDensity(&density);

        if (density != 0) {
            out_pixels.* = @floatFromInt(inches * density);
        } else {
            out_pixels.* = 0.0;
        }

        return accuracy;
    }

    pub fn convertPixelsToInches(pixels: f32, out_inches: *f32) ScreenPhysicalAccuracy {
        var density: i32 = 0;
        var accuracy = PlatformBind.computePhysicalScreenDensity(&density);

        if (density != 0) {
            out_inches.* = @floatFromInt(pixels / density);
        } else {
            out_inches.* = 0.0;
        }

        return accuracy;
    }

    pub fn showInputDeviceSelector(
        initiating_user_id: input_device_mapper.PlatformUserId,
        complete: ShowInputDeviceSelectorComplete,
    ) bool {
        _ = complete;
        _ = initiating_user_id;
        return false;
    }

    pub fn showPlatformUserSelector(
        initiating_input_device_id: input_device_mapper.InputDeviceId,
        selector_flags: PlatformUserSelectorFlags,
        complete: PlatformUserSelectionComplete,
    ) bool {
        _ = initiating_input_device_id;
        _ = selector_flags;
        _ = complete;
        return false;
    }
};
