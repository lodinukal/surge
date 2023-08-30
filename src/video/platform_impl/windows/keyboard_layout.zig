const std = @import("std");

const windows_platform = @import("windows.zig");
const windows_display = @import("display.zig");
const windows_dpi = @import("dpi.zig");
const windows_ime = @import("ime.zig");
const windows_raw_input = @import("raw_input.zig");
const windows_theme = @import("theme.zig");
const windows_util = @import("util.zig");

const win32 = @import("win32");
const channel = @import("../../../core/channel.zig");
const common = @import("../../../core/common.zig");
const rc = @import("../../../core/rc.zig");

const windows_window_state = @import("window_state.zig");

const pump_events = @import("../pump_events.zig");

const display = @import("../../display.zig");
const dpi = @import("../../dpi.zig");
const event = @import("../../event.zig");
const event_loop = @import("../../event_loop.zig");
const icon = @import("../../icon.zig");
const window = @import("../../window.zig");

const dwm = win32.graphics.dwm;
const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const pointer = win32.ui.input.pointer;
const wam = win32.ui.windows_and_messaging;
const z32 = win32.zig;