const std = @import("std");

const windows_platform = @import("windows.zig");

const win32 = @import("win32");
const common = @import("../../../core/common.zig");

const windows = @import("windows.zig");

const platform = @import("../platform_impl.zig");
const theme = @import("../../theme.zig");

const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const wam = win32.ui.windows_and_messaging;
const hi_dpi = win32.ui.hi_dpi;
const z32 = win32.zig;

const RtlGetVersion = *fn (version: *win32.system_information.OSVERSIONINFOW) foundation.NTSTATUS;
const lazyRtlGetVersion = windows_platform.getDllFunction(
    RtlGetVersion,
    "ntdll.dll",
    "RtlGetVersion",
);

const win10BuildVersion = common.Lazy(struct {
    pub fn init() ?u32 {
        if (lazyRtlGetVersion.get()) |rtlGetVersion| {
            var version_info = win32.system_information.OSVERSIONW{
                .dwOSVersionInfoSize = 0,
                .dwMajorVersion = 0,
                .dwMinorVersion = 0,
                .dwBuildNumber = 0,
                .dwPlatformId = 0,
                .szCSDVersion = []u16{0} ** 128,
            };
            const status = rtlGetVersion(&version_info);

            if (status >= 0 and version_info.dwMajorVersion == 0 and version_info.dwMinorVersion == 0) {
                return version_info.dwBuildNumber;
            }
        }
        return null;
    }
}, ?u32);

const darkModeSupported = common.Lazy(struct {
    pub fn init() bool {
        if (win10BuildVersion.get()) |buildVersion| {
            return buildVersion >= 17763;
        }
        return false;
    }
}, bool);

const darkThemeName = std.unicode.utf8ToUtf16LeStringLiteral("DarkMode_Explorer");
const lightThemeName = std.unicode.utf8ToUtf16LeStringLiteral("");

pub fn tryTheme(wnd: foundation.HWND, preferred_theme: ?theme.Theme) theme.Theme {
    if (darkModeSupported.get()) {
        const is_dark_mode = blk: {
            if (preferred_theme) |this_theme| {
                break :blk this_theme == theme.Theme.dark;
            }
            break :blk shouldUseDarkMode();
        };

        const use_theme: theme.Theme = if (is_dark_mode) theme.Theme.dark else theme.Theme.light;
        const theme_name = if (is_dark_mode) darkThemeName else lightThemeName;

        const status = win32.ui.controls.SetWindowTheme(wnd, theme_name, null);

        if (status == foundation.S_OK and setDarkModeForWindow(wnd, is_dark_mode)) {
            return use_theme;
        }
    }

    return theme.Theme.light;
}

const SetWindowCompositionAttribute = *fn (
    wnd: foundation.HWND,
    attr: *WINDOWCOMPOSITIONATTRIBDATA,
) callconv(.Win64) foundation.BOOL;

const WINDOWCOMPOSITIONATTRIB = u32;
const WCA_USEDARKMODECOLORS: WINDOWCOMPOSITIONATTRIB = 26;
const WINDOWCOMPOSITIONATTRIBDATA = extern struct {
    Attrib: WINDOWCOMPOSITIONATTRIB,
    pvData: *u8,
    cbData: usize,
};

const lazySetWindowCompositionAttribute = windows_platform.getDllFunction(
    SetWindowCompositionAttribute,
    "user32.dll",
    "SetWindowCompositionAttribute",
);

fn setDarkModeForWindow(wnd: foundation.HWND, is_dark_mode: bool) bool {
    if (lazySetWindowCompositionAttribute.get()) |setWindowCompositionAttribute| {
        var data = WINDOWCOMPOSITIONATTRIBDATA{
            .Attrib = WCA_USEDARKMODECOLORS,
            .pvData = &is_dark_mode,
            .cbData = @sizeOf(foundation.BOOL),
        };
        return setWindowCompositionAttribute(wnd, &data) != z32.FALSE;
    }
    return false;
}

fn shouldUseDarkMode() bool {
    return shouldAppsUseDarkMode() and !isHighContrast();
}

const ShouldAppsUseDarkMode = *fn () bool;
const lazyShouldAppsUseDarkMode = windows_platform.getDllFunction(
    ShouldAppsUseDarkMode,
    "uxtheme.dll",
    []u8{132},
);
fn shouldAppsUseDarkMode() bool {
    if (lazyShouldAppsUseDarkMode.get()) |shouldAppsUseDarkModeWin| {
        return shouldAppsUseDarkModeWin();
    }
    return false;
}

fn isHighContrast() bool {
    var high_contrast = win32.ui.accessibility.HIGHCONTRASTA{
        .cbSize = 0,
        .dwFlags = 0,
        .lpszDefaultScheme = null,
    };
    return wam.SystemParametersInfoA(
        wam.SPI_GETHIGHCONTRAST,
        @sizeOf(&high_contrast),
        &high_contrast,
        0,
    ) != z32.FALSE and (high_contrast.dwFlags & win32.ui.accessibility.HCF_HIGHCONTRASTON) != 0;
}
