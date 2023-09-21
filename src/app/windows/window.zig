const std = @import("std");

const math = @import("../../core/math.zig");

const win32 = @import("win32");

const application = @import("../generic/application.zig");
const WindowsApplication = @import("application.zig").WindowsApplication;

const window = @import("../generic/window.zig");
const GenericWindow = window.GenericWindow;

pub const WindowsWindow = struct {
    root: GenericWindow,

    owning_application: *WindowsApplication,
    hwnd: win32.foundation.HWND,
    region_width: i32,
    region_height: i32,
    window_mode: window.WindowMode,
    reference_count: std.atomic.Atomic(i32) = .{ .value = 0 },
    pre_fullscreen_window_placement: win32.ui.windows_and_messaging.WINDOWPLACEMENT = std.mem.zeroes(
        win32.ui.windows_and_messaging.WINDOWPLACEMENT,
    ),
    pre_parent_minimised_window_placement: win32.ui.windows_and_messaging.WINDOWPLACEMENT = std.mem.zeroes(
        win32.ui.windows_and_messaging.WINDOWPLACEMENT,
    ),
    virtual_width: i32,
    virtual_height: i32,
    aspect_ratio: f32,
    is_visible: bool,
    is_first_time_visible: bool,
    initially_minimised: bool,
    initially_maximised: bool,
    dpi_scale_factor: f32,
    handle_manual_dpi_changes: bool,

    const iunknown_interface = win32.system.com.IUnknown.VTable{
        .QueryInterface = @ptrCast(&WindowsWindow.QueryInterface),
        .AddRef = @ptrCast(&WindowsWindow.AddRef),
        .Release = @ptrCast(&WindowsWindow.Release),
    };

    const idrop_target = win32.system.ole.IDropTarget.VTable{
        .base = iunknown_interface,
        .DragEnter = @ptrCast(&WindowsWindow.DragEnter),
        .DragOver = @ptrCast(&WindowsWindow.DragOver),
        .DragLeave = @ptrCast(&WindowsWindow.DragLeave),
        .Drop = @ptrCast(&WindowsWindow.Drop),
    };

    pub fn getRoot(self: *WindowsWindow) *GenericWindow {
        return self.root;
    }

    pub const app_window_class = win32.zig.L("app-class");

    pub fn init() WindowsWindow {
        var wnd = WindowsWindow{
            .root = GenericWindow.init(),
        };

        return wnd;
    }

    // IUnknown
    fn QueryInterface(
        self: *const WindowsWindow,
        riid: ?*const win32.zig.Guid,
        ppvObject: ?*?*anyopaque,
    ) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT {
        if (std.mem.eql(u8, &riid.?.Bytes, &win32.system.ole.IID_IDropTarget.Bytes) or
            std.mem.eql(u8, &riid.?.Bytes, &win32.system.com.IID_IUnknown.Bytes))
        {
            self.addRef();
            ppvObject.?.* = @ptrCast(self);
            return win32.foundation.S_OK;
        } else {
            ppvObject.?.* = null;
            return win32.foundation.E_NOINTERFACE;
        }
    }

    fn AddRef(
        self: *const WindowsWindow,
    ) callconv(std.os.windows.WINAPI) u32 {
        return self.reference_count.fetchAdd(1, .Monotonic);
    }

    fn Release(
        self: *const WindowsWindow,
    ) callconv(std.os.windows.WINAPI) u32 {
        return self.reference_count.fetchSub(1, .Monotonic);
    }

    // IDropTarget
    fn DragEnter(
        self: *const WindowsWindow,
        pDataObj: ?*win32.system.ole.IDataObject,
        grfKeyState: u32,
        pt: win32.foundation.POINTL,
        pdwEffect: ?*u32,
    ) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT {
        _ = pdwEffect;
        _ = pt;
        _ = grfKeyState;
        _ = pDataObj;
        _ = self;
        return win32.foundation.E_NOTIMPL;
    }

    fn DragOver(
        self: *const WindowsWindow,
        grfKeyState: u32,
        pt: win32.foundation.POINTL,
        pdwEffect: ?*u32,
    ) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT {
        _ = pdwEffect;
        _ = pt;
        _ = grfKeyState;
        _ = self;
        return win32.foundation.E_NOTIMPL;
    }

    fn DragLeave(
        self: *const WindowsWindow,
    ) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT {
        _ = self;
        return win32.foundation.E_NOTIMPL;
    }

    fn Drop(
        self: *const WindowsWindow,
        pDataObj: ?*win32.system.ole.IDataObject,
        grfKeyState: u32,
        pt: win32.foundation.POINTL,
        pdwEffect: ?*u32,
    ) callconv(std.os.windows.WINAPI) std.os.windows.HRESULT {
        _ = pdwEffect;
        _ = pt;
        _ = grfKeyState;
        _ = pDataObj;
        _ = self;
    }
};
