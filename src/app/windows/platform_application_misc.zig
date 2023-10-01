const std = @import("std");

const math = @import("../../core/math.zig");

const win32 = @import("win32");

const application = @import("../generic//application.zig");
const GenericPlatformApplicationMisc = @import("../generic/platform_application_misc.zig").GenericPlatformApplicationMisc;

pub const WindowsPlatformApplicationMisc = struct {
    var getDpiForMonitor: ?*@TypeOf(win32.ui.hi_dpi.GetDpiForMonitor) = null;

    pub const preInit = GenericPlatformApplicationMisc.preInit;
    pub const init = GenericPlatformApplicationMisc.init;
    pub const postInit = GenericPlatformApplicationMisc.postInit;
    pub const teardown = GenericPlatformApplicationMisc.teardown;
    pub const loadPreInitModules = GenericPlatformApplicationMisc.loadPreInitModules;
    pub const loadStartupModules = GenericPlatformApplicationMisc.loadStartupModules;
    // pub const createConsoleOutputDevice = GenericPlatformApplicationMisc.createConsoleOutputDevice;
    // pub const getErrorOutputDevice = GenericPlatformApplicationMisc.getErrorOutputDevice;
    // pub const getFeedbackContext = GenericPlatformApplicationMisc.getFeedbackContext;
    pub const getPlatformInputDeviceManager = GenericPlatformApplicationMisc.getPlatformInputDeviceManager;
    // pub const createApplication = GenericPlatformApplicationMisc.createApplication;
    pub fn requestMinimise() void {
        win32.ui.windows_and_messaging.ShowWindow(
            win32.ui.input.keyboard_and_mouse.GetActiveWindow(),
            .MINIMIZE,
        );
    }
    pub fn isThisApplicationForeground() bool {
        var foreground_process: u32 = 0;
        win32.ui.windows_and_messaging.GetWindowThreadProcessId(
            win32.ui.windows_and_messaging.GetForegroundWindow(),
            &foreground_process,
        );
        return win32.system.threading.GetCurrentProcessId() == foreground_process;
    }
    pub const requiresVirtualKeyboard = GenericPlatformApplicationMisc.requiresVirtualKeyboard;
    fn winPumpMessages() void {
        var msg: win32.ui.windows_and_messaging.MSG = undefined;
        while (win32.ui.windows_and_messaging.PeekMessageA(
            &msg,
            null,
            0,
            0,
            .REMOVE,
        )) {
            win32.ui.windows_and_messaging.TranslateMessage(&msg);
            win32.ui.windows_and_messaging.DispatchMessageA(&msg);
        }
    }
    pub fn pumpMessages(from_main_loop: bool) void {
        if (!from_main_loop) {
            return;
        }
        winPumpMessages();
    }
    pub fn preventScreenSaver() void {
        const input = win32.ui.input.keyboard_and_mouse.INPUT{
            .type = .MOUSE,
            .Anonymous = .{ .mi = .{
                .dx = 0,
                .dy = 0,
                .mouseData = 0,
                .dwFlags = .MOVE,
                .time = 0,
                .dwExtraInfo = 0,
            } },
        };
        win32.ui.input.keyboard_and_mouse.SendInput(
            1,
            @ptrCast(&input),
            @sizeOf(win32.ui.input.keyboard_and_mouse.INPUT),
        );
    }
    pub const isScreensaverEnabled = GenericPlatformApplicationMisc.isScreensaverEnabled;
    pub const controlScreensaver = GenericPlatformApplicationMisc.controlScreensaver;
    pub fn getScreenPixelColour(x: i32, y: i32, in_gamma: ?f32) math.colour.LinearColour {
        _ = in_gamma;
        var hdc = win32.graphics.gdi.GetDC(null);
        defer win32.graphics.gdi.ReleaseDC(null, hdc);

        const color_ref = win32.graphics.gdi.GetPixel(hdc, x, y);

        return math.colour.Colour.init(
            color_ref & 0xFF,
            ((color_ref >> 8) & 0xFF00) >> 8,
            ((color_ref >> 16) & 0xFF0000) << 16,
            255,
        ).from_rgbe();
    }
    pub fn setHighDpiMode() void {
        if (std.DynLib.open("shcore.dll")) |shcore| {
            defer shcore.close();

            const setProcessDpiAwareness = @as(
                ?*@TypeOf(win32.ui.hi_dpi.SetProcessDpiAwareness),
                @ptrCast(
                    shcore.lookup("SetProcessDpiAwareness"),
                ),
            ) orelse return;
            getDpiForMonitor = @as(
                ?*@TypeOf(win32.ui.hi_dpi.GetDpiForMonitor),
                @ptrCast(
                    shcore.lookup("GetDpiForMonitor"),
                ),
            ) orelse return;
            const getProcessDpiAwareness = @as(
                ?*@TypeOf(win32.ui.hi_dpi.GetProcessDpiAwareness),
                @ptrCast(
                    shcore.lookup("GetProcessDpiAwareness"),
                ),
            ) orelse return;

            var current_awareness = win32.ui.hi_dpi.DPI_AWARENESS.UNAWARE;
            getProcessDpiAwareness.*(null, &current_awareness);

            if (current_awareness != .PER_MONITOR_AWARE) {
                //TODO(logging): log.warn("Setting process DPI awareness to PerMonitorAware");
                const result = setProcessDpiAwareness.*(.PER_MONITOR_AWARE);
                if (win32.zig.FAILED(result)) {
                    //TODO(logging): log.warn("Failed to set process DPI awareness to PerMonitorAware");
                }
            }
        } else |_| if (std.DynLib.open("user32.dll")) |user32| {
            defer user32.close();

            const setProcessDPIAware = @as(
                ?*@TypeOf(win32.ui.windows_and_messaging.SetProcessDPIAware),
                @ptrCast(
                    user32.lookup("SetProcessDPIAware"),
                ),
            ) orelse return;

            const failed = setProcessDPIAware.*() == 0;
            if (failed) {
                //TODO(logging): log.warn("Failed to set process DPI awareness to PerMonitorAware");
            }
        } else |_| {
            return;
        }
    }
    pub fn getDpiScaleFactorAtPoint(x: f32, y: f32) f32 {
        if (getDpiForMonitor) |foundGetDpiForMonitor| {
            const position = win32.foundation.POINT{
                .x = @intFromFloat(@trunc(x)),
                .y = @intFromFloat(@trunc(y)),
            };
            if (win32.graphics.gdi.MonitorFromPoint(
                position,
                .NEAREST,
            )) |monitor| {
                var dpi_x: u32 = 0;
                var dpi_y: u32 = 0;
                if (win32.zig.SUCCEEDED(foundGetDpiForMonitor.*(monitor, .EFFECTIVE_DPI, &dpi_x, &dpi_y))) {
                    return @as(f32, @floatCast(dpi_x)) / 96.0;
                }
            }
        }

        return 1.0;
    }
    pub const anchorWindowPositionTopLeft = GenericPlatformApplicationMisc.anchorWindowPositionTopLeft;
    pub const setGamepadsAllowed = GenericPlatformApplicationMisc.setGamepadsAllowed;
    pub const setGamepadsBlockDeviceFeedback = GenericPlatformApplicationMisc.setGamepadsBlockDeviceFeedback;
    pub const resetGamepadAssignments = GenericPlatformApplicationMisc.resetGamepadAssignments;
    pub const resetGamepadAssignmentToController = GenericPlatformApplicationMisc.resetGamepadAssignmentToController;
    pub const isControllerAssignedToGamepad = GenericPlatformApplicationMisc.isControllerAssignedToGamepad;
    pub const getGamepadControllerName = GenericPlatformApplicationMisc.getGamepadControllerName;
    // glyph for gamepad, TODO: later
    pub const enableMotionData = GenericPlatformApplicationMisc.enableMotionData;
    pub const isMotionDataEnabled = GenericPlatformApplicationMisc.isMotionDataEnabled;
    pub fn clipboardCopy(text: []const u8) void {
        if (win32.system.data_exchange.OpenClipboard(win32.ui.input.keyboard_and_mouse.GetActiveWindow()) == win32.zig.TRUE) {
            std.debug.assert(win32.system.data_exchange.EmptyClipboard() == win32.zig.TRUE);
            var global_mem = win32.system.memory.GlobalAlloc(
                .MEM_MOVEABLE,
                text.len + 1,
            );
            std.debug.assert(global_mem != 0);
            if (win32.system.memory.GlobalLock(global_mem)) |global_mem_ptr| {
                defer _ = win32.system.memory.GlobalUnlock(global_mem);
                var dest: [*]u8 = @ptrCast(global_mem_ptr);
                @memcpy(dest[0..text.len], text);
                dest[text.len] = 0;
            }
            if (win32.system.data_exchange.SetClipboardData(
                @intFromEnum(win32.system.system_services.CF_TEXT),
                @ptrFromInt(@as(usize, @bitCast(global_mem))),
            ) == null) {
                //TODO(logging): log.warn("Failed to set clipboard data");
            }
            std.debug.assert(win32.system.data_exchange.CloseClipboard() == win32.zig.TRUE);
        }
    }
    pub fn clipboardPaste(allocator: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
        if (win32.system.data_exchange.OpenClipboard(win32.ui.input.keyboard_and_mouse.GetActiveWindow()) == win32.zig.TRUE) {
            defer _ = win32.system.data_exchange.CloseClipboard();
            var global_mem = win32.system.data_exchange.GetClipboardData(@intFromEnum(
                win32.system.system_services.CF_UNICODETEXT,
            ));
            var is_unicode = true;
            if (global_mem == null) {
                global_mem = win32.system.data_exchange.GetClipboardData(@intFromEnum(
                    win32.system.system_services.CF_TEXT,
                ));
                is_unicode = false;
            }
            if (global_mem) |found_global_mem| {
                const isize_global_mem: isize = @bitCast(@intFromPtr(found_global_mem));
                if (win32.system.memory.GlobalLock(isize_global_mem)) |global_mem_ptr| {
                    defer _ = win32.system.memory.GlobalUnlock(isize_global_mem);
                    if (is_unicode) {
                        var mem_mp: [*:0]u16 = @alignCast(@ptrCast(global_mem_ptr));
                        const len = std.mem.len(mem_mp);
                        var mem_as_sentinel: []u16 = mem_mp[0..len];
                        return std.unicode.utf16leToUtf8Alloc(allocator, mem_as_sentinel) catch |err| switch (err) {
                            error.OutOfMemory => |oom| return oom,
                            else => allocator.dupe(u8, ""),
                        };
                    } else {
                        var mem_mp: [*:0]u8 = @ptrCast(global_mem_ptr);
                        const len = std.mem.len(mem_mp);
                        var mem_as_sentinel: []u8 = mem_mp[0..len];
                        return allocator.dupe(u8, @ptrCast(mem_as_sentinel));
                    }
                }
            } else return allocator.dupe(u8, "");
        } else {
            //TODO(logging): log.warn("Failed to open clipboard");
        }
        return allocator.dupe(u8, "");
    }
    pub const getPhysicalScreenDensity = GenericPlatformApplicationMisc.getPhysicalScreenDensity;
    pub const computePhysicalScreenDensity = GenericPlatformApplicationMisc.computePhysicalScreenDensity;
    pub const convertInchesToPixels = GenericPlatformApplicationMisc.convertInchesToPixels;
    pub const convertPixelsToInches = GenericPlatformApplicationMisc.convertPixelsToInches;
    pub const showInputDeviceSelector = GenericPlatformApplicationMisc.showInputDeviceSelector;
    pub const showPlatformUserSelector = GenericPlatformApplicationMisc.showPlatformUserSelector;

    // platform specific
    pub fn getMonitorDpi(monitor_info: *const application.MonitorInfo) i32 {
        if (getDpiForMonitor) |foundGetDpiForMonitor| {
            const monitor_dimension = win32.foundation.RECT{
                .left = monitor_info.display_rect.left,
                .top = monitor_info.display_rect.top,
                .right = monitor_info.display_rect.right,
                .bottom = monitor_info.display_rect.bottom,
            };

            if (win32.graphics.gdi.MonitorFromRect(
                &monitor_dimension,
                .NEAREST,
            )) |monitor| {
                var dpi_x: u32 = 0;
                var dpi_y: u32 = 0;
                if (win32.zig.SUCCEEDED(foundGetDpiForMonitor.*(monitor, .EFFECTIVE_DPI, &dpi_x, &dpi_y))) {
                    return @intCast(dpi_x);
                }
            }
        }
        return 96;
    }

    pub const GpuInfo = struct {
        vendor_id: u32 = 0,
        device_id: u32 = 0,
        dedicated_video_memory: u64 = 0,
    };
    pub fn getBestGpuInfo() ?GpuInfo {
        var dxgi_factory_1: ?*win32.graphics.dxgi.IDXGIFactory1 = null;
        if (win32.zig.FAILED(win32.graphics.dxgi.CreateDXGIFactory1(
            win32.graphics.dxgi.IID_IDXGIFactory1,
            @ptrCast(&dxgi_factory_1),
        )) or dxgi_factory_1 == null) return null;
        defer _ = dxgi_factory_1.?.*.IUnknown_Release();

        var best_desc = std.mem.zeroes(win32.graphics.dxgi.DXGI_ADAPTER_DESC);
        var temp_adapter: ?*win32.graphics.dxgi.IDXGIAdapter = null;
        var adapter_index: u32 = 0;
        while (dxgi_factory_1.?.IDXGIFactory_EnumAdapters(
            adapter_index,
            &temp_adapter,
        ) != win32.graphics.dxgi.DXGI_ERROR_NOT_FOUND) : (adapter_index += 1) {
            if (temp_adapter) |adapter| {
                defer _ = adapter.IUnknown_Release();
                var this_desc = std.mem.zeroes(win32.graphics.dxgi.DXGI_ADAPTER_DESC);
                if (win32.zig.FAILED(adapter.IDXGIAdapter_GetDesc(&this_desc))) continue;
                if (this_desc.DedicatedVideoMemory > best_desc.DedicatedVideoMemory or adapter_index == 0) {
                    best_desc = this_desc;
                }
            }
        }

        return GpuInfo{
            .vendor_id = best_desc.VendorId,
            .device_id = best_desc.DeviceId,
            .dedicated_video_memory = best_desc.DedicatedVideoMemory,
        };
    }

    pub const ConcurrencyModel = enum(u8) {
        single = 0,
        multi = 1,
    };
    pub fn coInitialise(mode: ?ConcurrencyModel) bool {
        const use_mode = mode orelse .single;
        const hr = win32.system.com.CoInitializeEx(
            null,
            if (use_mode == .single) .APARTMENTTHREADED else .MULTITHREADED,
        );
        return hr == @intFromEnum(win32.foundation.S_OK) or hr == @intFromEnum(win32.foundation.S_FALSE);
    }
};
