const std = @import("std");
const testing = std.testing;

const c = @import("c.zig");

const common = @import("../../core/common.zig");
const input_enums = @import("../../core/input_enums.zig");
const window = @import("../window.zig");
const display = @import("../display.zig");

const windows_display = @import("display.zig");

const DWORD = c.windows.DWORD;
const RECT = c.windows.RECT;

pub fn createWindow(info: window.WindowCreateInfo) !window.WindowHandle {
    const styles = get_window_style(.{
        .fullscreen = (info.mode == .fullscreen) or (info.mode == .exclusive_fullscreen),
        .multiwindow_fs = info.mode != .exclusive_fullscreen,
        .borderless = info.flags.borderless,
        .resizable = !info.flags.resized_disabled,
        .maximized = info.mode == .maximized,
        .no_activate_focus = info.flags.no_focus or info.flags.popup,
    });
    const style = styles.style;
    const ex_style = styles.ex_style;

    var window_rect: RECT = undefined;
    window_rect.left = info.rect.position.x;
    window_rect.top = info.rect.position.y;
    window_rect.right = info.rect.position.x + info.rect.size.x;
    window_rect.bottom = info.rect.position.y + info.rect.size.y;

    var rq_screen = display.getDisplayFromRect(info.rect) orelse display.getPrimaryDisplay().?;

    if (info.mode == .fullscreen or info.mode == .exclusive_fullscreen) {
        const screen_rect = common.Rect2i.from_components(
            display.getDisplayPosition(rq_screen).?,
            display.getDisplaySize(rq_screen).?,
        );
        window_rect.left = screen_rect.position.x;
        window_rect.top = screen_rect.position.y;
        window_rect.right = screen_rect.position.x + screen_rect.size.x;
        window_rect.bottom = screen_rect.position.y + screen_rect.size.y;
    } else {
        const srect = display.getDisplayUsableArea(rq_screen).?;
        var wpos = srect.position;
        if (wpos.eql(common.Vec2i.zero())) {
            wpos.x = common.clamp(
                wpos.x,
                srect.position.x,
                srect.position.x + srect.size.x - @divTrunc(info.rect.size.x, 3),
            );
            wpos.y = common.clamp(
                wpos.y,
                srect.position.y,
                srect.position.y + srect.size.y - @divTrunc(info.rect.size.y, 3),
            );
        }

        window_rect.left = wpos.x;
        window_rect.top = wpos.y;
        window_rect.right = wpos.x + info.rect.size.x;
        window_rect.bottom = wpos.y + info.rect.size.y;
    }

    const offset = windows_display.getDisplayOrigin().?;
    window_rect.left += offset.x;
    window_rect.top += offset.y;
    window_rect.right += offset.x;
    window_rect.bottom += offset.y;

    _ = c.windows.AdjustWindowRectEx(
        &window_rect,
        style,
        c.windows.FALSE,
        ex_style,
    );

    var window_id = windows_dense.items.len;

    {
        const sparse_index = windows_sparse.items.len;
        const data: *WindowData = try windows_sparse.addOne();
        data.* = WindowData{};

        const title_16 = try std.unicode.utf8ToUtf16LeWithNull(std.heap.c_allocator, info.title);
        defer std.heap.c_allocator.free(title_16);
        data.hwnd = c.windows.CreateWindowExW(
            ex_style,
            class_name,
            title_16,
            style,
            0,
            0,
            window_rect.right - window_rect.left,
            window_rect.bottom - window_rect.top,
            null,
            null,
            hinstance,
            @ptrCast(data),
        );

        if (data.hwnd == null) {
            _ = c.windows.MessageBoxA(
                null,
                "Failed to create window",
                "Error",
                0x00000000 | 0x00000030,
            );
            _ = windows_sparse.swapRemove(sparse_index);
        }

        if (info.mode == .fullscreen or info.mode == .exclusive_fullscreen) {
            data.fullscreen = true;
            if (info.mode == .exclusive_fullscreen) {
                data.multiwindow_fs = false;
            }
        }
        if (info.mode != .fullscreen and info.mode != .exclusive_fullscreen) {
            data.pre_fs_valid = true;
        }

        // TODO: Darkmode

        _ = c.windows.RegisterTouchWindow(data.hwnd, 0);
        c.windows.DragAcceptFiles(data.hwnd, c.windows.TRUE);

        // TODO: Touch and pen support

        if (info.mode == .maximized) {
            data.maximized = true;
            data.minimized = false;
        }

        if (info.mode == .minimized) {
            data.maximized = false;
            data.minimized = true;
        }

        data.last_pressure = 0;
        data.last_pressure_update = 0;
        data.last_tilt = common.Vec2f.zero();

        // IME
        data.im_himc = c.windows.ImmGetContext(data.hwnd);
        _ = c.windows.ImmAssociateContext(data.hwnd, @as(c.windows.HIMC, @ptrFromInt(0)));
        data.im_position = common.Vec2f.zero();

        if (info.mode == .fullscreen or info.mode == .exclusive_fullscreen or info.mode == .maximized) {
            var r: c.windows.RECT = undefined;
            _ = c.windows.GetClientRect(data.hwnd, &r);
            _ = c.windows.ClientToScreen(data.hwnd, @ptrCast(&r.left));
            _ = c.windows.ClientToScreen(data.hwnd, @ptrCast(&r.right));

            data.last_pos = common.Vec2i.init(r.left, r.top).sub(
                windows_display.getDisplayOrigin().?,
            );
            data.size = common.Vec2i.init(r.right - r.left, r.bottom - r.top);
        } else {
            data.last_pos = info.rect.position;
            data.size = info.rect.size;
        }

        const sparse_ref = try windows_dense.addOne();
        sparse_ref.* = sparse_index;
    }

    return @intCast(window_id);
}

const WindowStyleInfo = struct {
    fullscreen: bool,
    multiwindow_fs: bool,
    borderless: bool,
    resizable: bool,
    maximized: bool,
    no_activate_focus: bool,
};

fn get_window_style(info: WindowStyleInfo) struct { style: DWORD, ex_style: DWORD } {
    var style: DWORD = 0;
    var ex_style: DWORD = c.WS_EX_WINDOWEDGE;

    ex_style |= c.WS_EX_APPWINDOW;
    style |= c.WS_VISIBLE;

    if (info.fullscreen or info.borderless) {
        style |= c.WS_POPUP;
        if (info.fullscreen and info.multiwindow_fs) {
            style |= c.WS_BORDER;
        }
    } else {
        if (info.resizable) {
            if (info.maximized) {
                style |= c.WS_OVERLAPPED | c.WS_MAXIMIZE;
            } else {
                style |= c.WS_OVERLAPPED;
            }
        } else {
            style |= c.WS_OVERLAPPED | c.WS_CAPTION | c.WS_SYSMENU | c.WS_MINIMIZE;
        }
    }

    if (info.no_activate_focus) {
        ex_style |= c.WS_EX_TOPMOST | c.WS_EX_NOACTIVATE;
    }

    if (!info.borderless and !info.no_activate_focus) {
        style |= c.WS_VISIBLE;
    }

    return .{
        .style = style | c.WS_CLIPCHILDREN | c.WS_CLIPSIBLINGS,
        .ex_style = ex_style | c.WS_EX_ACCEPTFILES,
    };
}

var windows_dense: std.ArrayList(usize) = std.ArrayList(usize).init(std.heap.c_allocator);
var windows_sparse: std.ArrayList(WindowData) = std.ArrayList(WindowData).init(std.heap.c_allocator);

const WindowData = struct {
    hwnd: c.windows.HWND = null,

    pre_fs_valid: bool = false,
    pre_fs_rect: common.Rect2i = common.Rect2i.zero(),
    maximized: bool = false,
    minimized: bool = false,
    fullscreen: bool = false,
    multiwindow_fs: bool = false,
    resizable: bool = true,
    focused: bool = false,
    was_maximized: bool = false,
    always_on_top: bool = false,
    no_focus: bool = false,
    has_focus: bool = false,
    exclusive: bool = false,
    mouse_passthrough: bool = false,

    saved_wparam: c.windows.WPARAM = 0,
    saved_lparam: c.windows.LPARAM = 0,

    move_timer_id: u32 = 0,
    focus_timer_id: u32 = 0,

    windows_touch_context: c.windows.HANDLE = null,
    wacom_touch_log_context: ?c.windows.LOGCONTEXTW = null,
    min_pressure: i32 = 0,
    max_pressure: i32 = 0,
    tilt_supported: bool = false,
    pen_inverted: bool = false,
    block_mouse: bool = false,

    last_pressure_update: i32 = 0,
    last_pressure: f32 = 0,
    last_tilt: common.Vec2f = common.Vec2f.zero(),
    last_pen_inverted: bool = false,

    min_size: common.Vec2i = common.Vec2i.zero(),
    max_size: common.Vec2i = common.Vec2i.zero(),
    size: common.Vec2i = common.Vec2i.zero(),

    window_rect: common.Rect2i = common.Rect2i.zero(),
    last_pos: common.Vec2i = common.Vec2i.zero(),

    // IME
    im_himc: c.windows.HIMC = null,
    im_position: common.Vec2f = common.Vec2f.zero(),
    ime_active: bool = false,
    ime_in_progress: bool = false,
    ime_supress_next_keyup: bool = false,

    layered_window: bool = false,

    is_parent: bool = false,
};

pub const L = std.unicode.utf8ToUtf16LeStringLiteral;
pub const class_name = L("zig_window_class");
var hinstance: c.windows.HINSTANCE = null;
pub fn init() !void {
    hinstance = c.windows.GetModuleHandleW(null);
    // register class
    var window_class = std.mem.zeroInit(c.windows.WNDCLASSEXW, .{});
    window_class.cbSize = @sizeOf(c.windows.WNDCLASSEXW);
    window_class.style = c.windows.CS_OWNDC | c.windows.CS_DBLCLKS;
    window_class.lpfnWndProc = &wnd_proc;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = hinstance;
    window_class.hIcon = c.windows.LoadIconW(
        null,
        c.MAKEINTRESOURCEW(32517),
    );
    window_class.hCursor = null;
    window_class.hbrBackground = null;
    window_class.lpszMenuName = null;
    window_class.lpszClassName = class_name;

    if (c.windows.RegisterClassExW(&window_class) == c.windows.FALSE) {
        _ = c.windows.MessageBoxW(
            null,
            L("Failed to register window class"),
            L("Error"),
            0x00000000 | 0x00000030,
        );
    }
}

pub fn deinit() void {
    _ = c.windows.UnregisterClassW(class_name, hinstance);
}

fn wnd_proc(hwnd: c.windows.HWND, msg: c.windows.UINT, wparam: c.windows.WPARAM, lparam: c.windows.LPARAM) callconv(.C) c.windows.LRESULT {
    // const data: ?*WindowData = @ptrFromInt(@as(usize, @intCast(c.windows.GetWindowLongPtrW(hwnd, c.windows.GWLP_USERDATA))));
    // if (data == null) {
    //     return c.windows.DefWindowProcW(hwnd, msg, wparam, lparam);
    // }

    std.debug.print("msg: {}\n", .{msg});
    switch (msg) {
        c.windows.WM_CREATE => {},
        else => {},
    }

    return c.windows.DefWindowProcW(hwnd, msg, wparam, lparam);
}
