const std = @import("std");

const win32 = @import("win32");

const GenericPlatformApplicationMisc = @import("../generic/platform_application_misc.zig").GenericPlatformApplicationMisc;

const WindowsPlatformApplicationMisc = struct {
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
    pub const getScreenPixelColour = GenericPlatformApplicationMisc.getScreenPixelColour;
    pub const setHighDpiMode = GenericPlatformApplicationMisc.setHighDpiMode;
    pub const getDpiScaleFactorAtPoint = GenericPlatformApplicationMisc.getDpiScaleFactorAtPoint;
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
    pub const clipboardCopy = GenericPlatformApplicationMisc.clipboardCopy;
    pub const clipboardPaste = GenericPlatformApplicationMisc.clipboardPaste;
    pub const getPhysicalScreenDensity = GenericPlatformApplicationMisc.getPhysicalScreenDensity;
    pub const computePhysicalScreenDensity = GenericPlatformApplicationMisc.computePhysicalScreenDensity;
    pub const convertInchesToPixels = GenericPlatformApplicationMisc.convertInchesToPixels;
    pub const convertPixelsToInches = GenericPlatformApplicationMisc.convertPixelsToInches;
    pub const showInputDeviceSelector = GenericPlatformApplicationMisc.showInputDeviceSelector;
    pub const showPlatformUserSelector = GenericPlatformApplicationMisc.showPlatformUserSelector;
};
