const std = @import("std");

const win32 = @import("win32");

const platform_application_misc = @import("../generic/platform_application_misc.zig");
const PlatformApplicationMisc = platform_application_misc.PlatformApplicationMisc;

const WindowsWindow = @import("window.zig").WindowsWindow;

pub const TaskbarProgressState = enum(u8) {
    no_progress = 0x0,
    intermediate = 0x1,
    normal = 0x2,
    @"error" = 0x4,
    paused = 0x8,
};

pub const TaskbarList = struct {
    taskbar_list_3: ?*win32.ui.shell.ITaskbarList3,

    pub fn init() TaskbarList {
        var created: TaskbarList = .{
            .taskbar_list_3 = null,
        };

        if (PlatformApplicationMisc.coInitialise(null)) {
            if (win32.system.com.CoCreateInstance(
                win32.ui.shell.IID_ITaskbarList,
                null,
                .INPROC_SERVER,
                win32.ui.shell.IID_ITaskbarList3,
                @ptrCast(&created.taskbar_list_3),
            ) != @intFromEnum(win32.foundation.S_OK)) {
                created.taskbar_list_3 = null;
            }
        }

        return created;
    }

    pub fn deinit(self: *TaskbarList) void {
        if (self.taskbar_list_3) |tl3| {
            if (PlatformApplicationMisc.coInitialise(null)) {
                tl3.IUnknown_Release();
            }
        }
        self.taskbar_list_3 = null;
    }

    pub fn setOverlayIcon(
        self: *TaskbarList,
        allocator: std.mem.Allocator,
        wnd: win32.foundation.HWND,
        icon: win32.ui.windows_and_messaging.HICON,
        description: []const u8,
    ) !void {
        if (self.taskbar_list_3) |tl3| {
            var psz_description = try std.unicode.utf8ToUtf16LeWithNull(allocator, description);
            defer allocator.free(psz_description);
            tl3.ITaskbarList3_SetOverlayIcon(wnd, icon, @ptrCast(psz_description));
        }
    }

    pub fn setProgressValue(
        self: *TaskbarList,
        wnd: win32.foundation.HWND,
        current: u64,
        maximum: u64,
    ) void {
        if (self.taskbar_list_3) |tl3| {
            tl3.ITaskbarList3_SetProgressValue(wnd, current, maximum);
        }
    }

    pub fn setProgressState(
        self: *TaskbarList,
        wnd: win32.foundation.HWND,
        state: TaskbarProgressState,
    ) void {
        if (self.taskbar_list_3) |tl3| {
            tl3.ITaskbarList3_SetProgressState(wnd, @enumFromInt(@intFromEnum(state)));
        }
    }
};

pub const DeferredWindowsMessage = struct {
    window: *WindowsWindow,
    hwnd: win32.foundation.HWND,
    msg: std.os.windows.UINT,
    wparam: win32.foundation.WPARAM,
    lparam: win32.foundation.LPARAM,
    x: i32,
    y: i32,
    raw_input_flags: u32,
};

pub const WindowsDragDropOperationType = enum {
    drag_enter,
    drag_over,
    drag_leave,
    drop,
};

pub const DragDropOleData = struct {
    type: packed struct {
        text: bool = false,
        files: bool = false,
    },
    operation_text: []u8,
    operation_filenames: [][]u8,
};

pub const DeferedWindowsDragDropOperation = struct {
    operation_type: WindowsDragDropOperationType,
    hwnd: ?win32.foundation.HWND = null,
    ole_data: DragDropOleData,
    key_state: std.os.windows.DWORD = 0,
    cursor_position: win32.foundation.POINTL = .{ .x = 0, .y = 0 },

    pub fn dragEnter(
        in_hwnd: win32.foundation.HWND,
        in_ole_data: *const DragDropOleData,
        in_key_state: std.os.windows.DWORD,
        in_cursor_position: win32.foundation.POINTL,
    ) DeferedWindowsDragDropOperation {
        return DeferedWindowsDragDropOperation{
            .operation_type = .drag_enter,
            .hwnd = in_hwnd,
            .ole_data = *in_ole_data,
            .key_state = in_key_state,
            .cursor_position = in_cursor_position,
        };
    }

    pub fn dragOver(
        in_hwnd: win32.foundation.HWND,
        in_key_state: std.os.windows.DWORD,
        in_cursor_position: win32.foundation.POINTL,
    ) DeferedWindowsDragDropOperation {
        return DeferedWindowsDragDropOperation{
            .operation_type = .drag_over,
            .hwnd = in_hwnd,
            .key_state = in_key_state,
            .cursor_position = in_cursor_position,
        };
    }

    pub fn dragLeave(
        in_hwnd: win32.foundation.HWND,
    ) DeferedWindowsDragDropOperation {
        return DeferedWindowsDragDropOperation{
            .operation_type = .drag_leave,
            .hwnd = in_hwnd,
        };
    }

    pub fn drop(
        in_hwnd: win32.foundation.HWND,
        in_ole_data: *const DragDropOleData,
        in_key_state: std.os.windows.DWORD,
        in_cursor_position: win32.foundation.POINTL,
    ) DeferedWindowsDragDropOperation {
        return DeferedWindowsDragDropOperation{
            .operation_type = .drop,
            .hwnd = in_hwnd,
            .ole_data = *in_ole_data,
            .key_state = in_key_state,
            .cursor_position = in_cursor_position,
        };
    }
};

pub const WindowsMessageHandler = struct {
    pub const Virtual = struct {
        processMessage: ?*const fn (
            self: *void,
            hwnd: win32.foundation.HWND,
            msg: std.os.windows.UINT,
            wparam: win32.foundation.WPARAM,
            lparam: win32.foundation.LPARAM,
        ) bool = null,
    };
    virtual: ?*const Virtual = null,

    pub fn processMessage(
        self: *WindowsMessageHandler,
        hwnd: win32.foundation.HWND,
        msg: std.os.windows.UINT,
        wparam: win32.foundation.WPARAM,
        lparam: win32.foundation.LPARAM,
    ) bool {
        if (self.virtual) |v| {
            if (v.processMessage) |f| {
                return f(self, hwnd, msg, wparam, lparam);
            }
        }
        return true;
    }
};

pub const WindowsApplication = struct {};
