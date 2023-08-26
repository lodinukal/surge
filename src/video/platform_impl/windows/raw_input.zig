const std = @import("std");

const win32 = @import("win32");
const common = @import("../../../core/common.zig");

const windows = @import("windows.zig");

const platform = @import("../platform_impl.zig");
const dpi = @import("../../dpi.zig");
const event = @import("../../event.zig");
const event_loop = @import("../../event_loop.zig");
const icon = @import("../../icon.zig");
const keyboard = @import("../../keyboard.zig");
const theme = @import("../../theme.zig");

const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const input = win32.ui.input;
const wam = win32.ui.windows_and_messaging;
const z32 = win32.zig;

pub fn getRawInputDeviceList(allocator: std.mem.Allocator) !?[]input.RAWINPUTDEVICELIST {
    const list_size = @sizeOf(input.RAWINPUTDEVICELIST);

    var num_devices: usize = 0;
    const status = input.GetRawInputDeviceList(null, &num_devices, list_size);

    if (status == std.math.maxInt(u32)) {
        return null;
    }

    var buffer = try std.ArrayList(input.RAWINPUTDEVICELIST).initCapacity(allocator, num_devices);
    defer buffer.deinit();

    const num_stored = input.GetRawInputDeviceList(
        &buffer.items,
        &num_devices,
        list_size,
    );
    if (num_stored == std.math.maxInt(u32)) {
        return null;
    }

    common.assert(
        num_devices == num_stored,
        "getRawInputDeviceList: num_devices({}) is not equal to num_stored({})",
        .{ num_devices, num_stored },
    );

    buffer.shrinkAndFree(num_devices);

    return buffer.toOwnedSlice();
}

pub const RawDeviceInfo = union(enum) {
    mouse: input.RID_DEVICE_INFO_MOUSE,
    keyboard: input.RID_DEVICE_INFO_KEYBOARD,
    hid: input.RID_DEVICE_INFO_HID,

    pub fn fromStructure(info: input.RID_DEVICE_INFO) RawDeviceInfo {
        switch (info.dwType) {
            .MOUSE => return .{ .mouse = info.Anonymous.mouse },
            .KEYBOARD => return .{ .keyboard = info.Anonymous.keyboard },
            .HID => return .{ .hid = info.Anonymous.hid },
        }
    }
};

pub fn getRawInputDeviceInfo(handle: foundation.HANDLE) ?RawDeviceInfo {
    var info = std.mem.zeroes(input.RID_DEVICE_INFO);
    const info_size = @sizeOf(input.RID_DEVICE_INFO);

    info.cbSize = info_size;

    var minimum_size: usize = 0;
    const status = input.GetRawInputDeviceInfoW(
        handle,
        input.RIDI_DEVICEINFO,
        &info,
        &minimum_size,
    );

    if (status == std.math.maxInt(u32) or status == 0) {
        return null;
    }

    common.assert(
        info_size == status,
        "getRawInputDeviceInfo: info_size({}) is not equal to status({})",
        .{ info_size, status },
    );

    return RawDeviceInfo.fromStructure(info);
}

pub fn getRawInputDeviceName(allocator: std.mem.Allocator, handle: foundation.HANDLE) std.mem.Allocator.Error!?[]u8 {
    var minimum_size: usize = 0;
    const status = input.GetRawInputDeviceInfoW(
        handle,
        input.RIDI_DEVICENAME,
        null,
        &minimum_size,
    );

    if (status != 0) {
        return null;
    }

    var name = try std.ArrayList(u16).initCapacity(allocator, minimum_size);
    defer name.deinit();
    const get_name_status = input.GetRawInputDeviceInfoW(
        handle,
        input.RIDI_DEVICENAME,
        &name.items,
        &minimum_size,
    );

    if (get_name_status == std.math.maxInt(u32) or get_name_status == 0) {
        return null;
    }

    common.assert(
        minimum_size == get_name_status,
        "getRawInputDeviceName: minimum_size({}) is not equal to get_name_status({})",
        .{ minimum_size, get_name_status },
    );

    name.shrinkAndFree(minimum_size);
    const result = try std.unicode.utf16leToUtf8Alloc(allocator, name.items);

    return result;
}

pub fn registerRawInputDevices(devices: []const input.RAWINPUTDEVICE) bool {
    const device_size = @sizeOf(input.RAWINPUTDEVICE);

    return input.RegisterRawInputDevices(
        devices,
        devices.len,
        device_size,
    ) != z32.FALSE;
}

pub fn registerAllMiceAndKeyboardForRawInput(
    wnd: foundation.HWND,
    filter: event_loop.DeviceEvents,
) bool {
    var mutating_wnd = wnd;
    const flags = switch (filter) {
        .never => blk: {
            mutating_wnd = @ptrFromInt(0);
            break :blk input.RIDEV_REMOVE;
        },
        .when_focused => input.RIDEV_DEVNOTIFY,
        .always => input.RIDEV_DEVNOTIFY | input.RIDEV_INPUTSINK,
    };

    const devices = [2]input.RAWINPUTDEVICE{
        .{
            .usUsagePage = input.HID_USAGE_PAGE_GENERIC,
            .usUsage = input.HID_USAGE_GENERIC_MOUSE,
            .dwFlags = flags,
            .hwndTarget = mutating_wnd,
        },
        .{
            .usUsagePage = input.HID_USAGE_PAGE_GENERIC,
            .usUsage = input.HID_USAGE_GENERIC_KEYBOARD,
            .dwFlags = flags,
            .hwndTarget = mutating_wnd,
        },
    };

    return registerRawInputDevices(&devices);
}

pub fn getRawInputData(ri: input.HRAWINPUT) ?input.RAWINPUT {
    var data = std.mem.zeroes(input.RAWINPUT);
    var data_size: usize = 0;
    const header_size = @sizeOf(input.RAWINPUTHEADER);

    const status = input.GetRawInputData(
        ri,
        input.RID_INPUT,
        &data,
        &data_size,
        header_size,
    );

    if (status == std.math.maxInt(u32) or status == 0) {
        return null;
    }

    return data;
}

fn buttonFlagsToElementStats(button_flags: u32, down_flag: u32, up_flag: u32) ?event.ElementState {
    if (button_flags & down_flag != 0) {
        return .pressed;
    } else if (button_flags & up_flag != 0) {
        return .released;
    } else {
        return null;
    }
}

pub fn getRawMouseButtonState(button_flags: u32) [3]?event.ElementState {
    return [3]?event.ElementState{
        buttonFlagsToElementStats(
            button_flags,
            wam.RI_MOUSE_LEFT_BUTTON_DOWN,
            wam.RI_MOUSE_LEFT_BUTTON_DOWN,
        ),
        buttonFlagsToElementStats(
            button_flags,
            wam.RI_MOUSE_MIDDLE_BUTTON_DOWN,
            wam.RI_MOUSE_MIDDLE_BUTTON_DOWN,
        ),
        buttonFlagsToElementStats(
            button_flags,
            wam.RI_MOUSE_DOWN_BUTTON_DOWN,
            wam.RI_MOUSE_DOWN_BUTTON_DOWN,
        ),
    };
}
