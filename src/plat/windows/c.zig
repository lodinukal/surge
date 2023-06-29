pub const windows = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cInclude("windows.h");
    @cInclude("shellapi.h");
    @cInclude("wintab.h");
});

pub fn MAKEINTRESOURCEW(id: anytype) windows.LPCWSTR {
    @setRuntimeSafety(false);
    return @as(windows.LPWSTR, @as(windows.ULONG_PTR, @as(windows.WORD, @intCast(id))));
}

pub const WINDOW_STYLE = enum(u32) {
    OVERLAPPED = 0,
    POPUP = 2147483648,
    CHILD = 1073741824,
    MINIMIZE = 536870912,
    VISIBLE = 268435456,
    DISABLED = 134217728,
    CLIPSIBLINGS = 67108864,
    CLIPCHILDREN = 33554432,
    MAXIMIZE = 16777216,
    CAPTION = 12582912,
    BORDER = 8388608,
    DLGFRAME = 4194304,
    VSCROLL = 2097152,
    HSCROLL = 1048576,
    SYSMENU = 524288,
    THICKFRAME = 262144,
    GROUP = 131072,
    TABSTOP = 65536,
    // MINIMIZEBOX = 131072, this enum value conflicts with GROUP
    // MAXIMIZEBOX = 65536, this enum value conflicts with TABSTOP
    // TILED = 0, this enum value conflicts with OVERLAPPED
    // ICONIC = 536870912, this enum value conflicts with MINIMIZE
    // SIZEBOX = 262144, this enum value conflicts with THICKFRAME
    TILEDWINDOW = 13565952,
    // OVERLAPPEDWINDOW = 13565952, this enum value conflicts with TILEDWINDOW
    POPUPWINDOW = 2156396544,
    // CHILDWINDOW = 1073741824, this enum value conflicts with CHILD
    ACTIVECAPTION = 1,
    _,
    pub fn initFlags(o: struct {
        OVERLAPPED: u1 = 0,
        POPUP: u1 = 0,
        CHILD: u1 = 0,
        MINIMIZE: u1 = 0,
        VISIBLE: u1 = 0,
        DISABLED: u1 = 0,
        CLIPSIBLINGS: u1 = 0,
        CLIPCHILDREN: u1 = 0,
        MAXIMIZE: u1 = 0,
        CAPTION: u1 = 0,
        BORDER: u1 = 0,
        DLGFRAME: u1 = 0,
        VSCROLL: u1 = 0,
        HSCROLL: u1 = 0,
        SYSMENU: u1 = 0,
        THICKFRAME: u1 = 0,
        GROUP: u1 = 0,
        TABSTOP: u1 = 0,
        TILEDWINDOW: u1 = 0,
        POPUPWINDOW: u1 = 0,
        ACTIVECAPTION: u1 = 0,
    }) WINDOW_STYLE {
        return @as(WINDOW_STYLE, @enumFromInt((if (o.OVERLAPPED == 1) @intFromEnum(WINDOW_STYLE.OVERLAPPED) else 0) | (if (o.POPUP == 1) @intFromEnum(WINDOW_STYLE.POPUP) else 0) | (if (o.CHILD == 1) @intFromEnum(WINDOW_STYLE.CHILD) else 0) | (if (o.MINIMIZE == 1) @intFromEnum(WINDOW_STYLE.MINIMIZE) else 0) | (if (o.VISIBLE == 1) @intFromEnum(WINDOW_STYLE.VISIBLE) else 0) | (if (o.DISABLED == 1) @intFromEnum(WINDOW_STYLE.DISABLED) else 0) | (if (o.CLIPSIBLINGS == 1) @intFromEnum(WINDOW_STYLE.CLIPSIBLINGS) else 0) | (if (o.CLIPCHILDREN == 1) @intFromEnum(WINDOW_STYLE.CLIPCHILDREN) else 0) | (if (o.MAXIMIZE == 1) @intFromEnum(WINDOW_STYLE.MAXIMIZE) else 0) | (if (o.CAPTION == 1) @intFromEnum(WINDOW_STYLE.CAPTION) else 0) | (if (o.BORDER == 1) @intFromEnum(WINDOW_STYLE.BORDER) else 0) | (if (o.DLGFRAME == 1) @intFromEnum(WINDOW_STYLE.DLGFRAME) else 0) | (if (o.VSCROLL == 1) @intFromEnum(WINDOW_STYLE.VSCROLL) else 0) | (if (o.HSCROLL == 1) @intFromEnum(WINDOW_STYLE.HSCROLL) else 0) | (if (o.SYSMENU == 1) @intFromEnum(WINDOW_STYLE.SYSMENU) else 0) | (if (o.THICKFRAME == 1) @intFromEnum(WINDOW_STYLE.THICKFRAME) else 0) | (if (o.GROUP == 1) @intFromEnum(WINDOW_STYLE.GROUP) else 0) | (if (o.TABSTOP == 1) @intFromEnum(WINDOW_STYLE.TABSTOP) else 0) | (if (o.TILEDWINDOW == 1) @intFromEnum(WINDOW_STYLE.TILEDWINDOW) else 0) | (if (o.POPUPWINDOW == 1) @intFromEnum(WINDOW_STYLE.POPUPWINDOW) else 0) | (if (o.ACTIVECAPTION == 1) @intFromEnum(WINDOW_STYLE.ACTIVECAPTION) else 0)));
    }
};
pub const WS_OVERLAPPED: windows.DWORD = @intFromEnum(WINDOW_STYLE.OVERLAPPED);
pub const WS_POPUP: windows.DWORD = @intFromEnum(WINDOW_STYLE.POPUP);
pub const WS_CHILD: windows.DWORD = @intFromEnum(WINDOW_STYLE.CHILD);
pub const WS_MINIMIZE: windows.DWORD = @intFromEnum(WINDOW_STYLE.MINIMIZE);
pub const WS_VISIBLE: windows.DWORD = @intFromEnum(WINDOW_STYLE.VISIBLE);
pub const WS_DISABLED: windows.DWORD = @intFromEnum(WINDOW_STYLE.DISABLED);
pub const WS_CLIPSIBLINGS: windows.DWORD = @intFromEnum(WINDOW_STYLE.CLIPSIBLINGS);
pub const WS_CLIPCHILDREN: windows.DWORD = @intFromEnum(WINDOW_STYLE.CLIPCHILDREN);
pub const WS_MAXIMIZE: windows.DWORD = @intFromEnum(WINDOW_STYLE.MAXIMIZE);
pub const WS_CAPTION: windows.DWORD = @intFromEnum(WINDOW_STYLE.CAPTION);
pub const WS_BORDER: windows.DWORD = @intFromEnum(WINDOW_STYLE.BORDER);
pub const WS_DLGFRAME: windows.DWORD = @intFromEnum(WINDOW_STYLE.DLGFRAME);
pub const WS_VSCROLL: windows.DWORD = @intFromEnum(WINDOW_STYLE.VSCROLL);
pub const WS_HSCROLL: windows.DWORD = @intFromEnum(WINDOW_STYLE.HSCROLL);
pub const WS_SYSMENU: windows.DWORD = @intFromEnum(WINDOW_STYLE.SYSMENU);
pub const WS_THICKFRAME: windows.DWORD = @intFromEnum(WINDOW_STYLE.THICKFRAME);
pub const WS_GROUP: windows.DWORD = @intFromEnum(WINDOW_STYLE.GROUP);
pub const WS_TABSTOP: windows.DWORD = @intFromEnum(WINDOW_STYLE.TABSTOP);
pub const WS_MINIMIZEBOX: windows.DWORD = @intFromEnum(WINDOW_STYLE.GROUP);
pub const WS_MAXIMIZEBOX: windows.DWORD = @intFromEnum(WINDOW_STYLE.TABSTOP);
pub const WS_TILED: windows.DWORD = @intFromEnum(WINDOW_STYLE.OVERLAPPED);
pub const WS_ICONIC: windows.DWORD = @intFromEnum(WINDOW_STYLE.MINIMIZE);
pub const WS_SIZEBOX: windows.DWORD = @intFromEnum(WINDOW_STYLE.THICKFRAME);
pub const WS_TILEDWINDOW: windows.DWORD = @intFromEnum(WINDOW_STYLE.TILEDWINDOW);
pub const WS_OVERLAPPEDWINDOW: windows.DWORD = @intFromEnum(WINDOW_STYLE.TILEDWINDOW);
pub const WS_POPUPWINDOW: windows.DWORD = @intFromEnum(WINDOW_STYLE.POPUPWINDOW);
pub const WS_CHILDWINDOW: windows.DWORD = @intFromEnum(WINDOW_STYLE.CHILD);
pub const WS_ACTIVECAPTION: windows.DWORD = @intFromEnum(WINDOW_STYLE.ACTIVECAPTION);

pub const WINDOW_EX_STYLE = enum(u32) {
    DLGMODALFRAME = 1,
    NOPARENTNOTIFY = 4,
    TOPMOST = 8,
    ACCEPTFILES = 16,
    TRANSPARENT = 32,
    MDICHILD = 64,
    TOOLWINDOW = 128,
    WINDOWEDGE = 256,
    CLIENTEDGE = 512,
    CONTEXTHELP = 1024,
    RIGHT = 4096,
    LEFT = 0,
    RTLREADING = 8192,
    // LTRREADING = 0, this enum value conflicts with LEFT
    LEFTSCROLLBAR = 16384,
    // RIGHTSCROLLBAR = 0, this enum value conflicts with LEFT
    CONTROLPARENT = 65536,
    STATICEDGE = 131072,
    APPWINDOW = 262144,
    OVERLAPPEDWINDOW = 768,
    PALETTEWINDOW = 392,
    LAYERED = 524288,
    NOINHERITLAYOUT = 1048576,
    NOREDIRECTIONBITMAP = 2097152,
    LAYOUTRTL = 4194304,
    COMPOSITED = 33554432,
    NOACTIVATE = 134217728,
    _,
    pub fn initFlags(o: struct {
        DLGMODALFRAME: u1 = 0,
        NOPARENTNOTIFY: u1 = 0,
        TOPMOST: u1 = 0,
        ACCEPTFILES: u1 = 0,
        TRANSPARENT: u1 = 0,
        MDICHILD: u1 = 0,
        TOOLWINDOW: u1 = 0,
        WINDOWEDGE: u1 = 0,
        CLIENTEDGE: u1 = 0,
        CONTEXTHELP: u1 = 0,
        RIGHT: u1 = 0,
        LEFT: u1 = 0,
        RTLREADING: u1 = 0,
        LEFTSCROLLBAR: u1 = 0,
        CONTROLPARENT: u1 = 0,
        STATICEDGE: u1 = 0,
        APPWINDOW: u1 = 0,
        OVERLAPPEDWINDOW: u1 = 0,
        PALETTEWINDOW: u1 = 0,
        LAYERED: u1 = 0,
        NOINHERITLAYOUT: u1 = 0,
        NOREDIRECTIONBITMAP: u1 = 0,
        LAYOUTRTL: u1 = 0,
        COMPOSITED: u1 = 0,
        NOACTIVATE: u1 = 0,
    }) WINDOW_EX_STYLE {
        return @as(
            WINDOW_EX_STYLE,
            @enumFromInt(
                (if (o.DLGMODALFRAME == 1) @intFromEnum(WINDOW_EX_STYLE.DLGMODALFRAME) else 0) | (if (o.NOPARENTNOTIFY == 1) @intFromEnum(WINDOW_EX_STYLE.NOPARENTNOTIFY) else 0) | (if (o.TOPMOST == 1) @intFromEnum(WINDOW_EX_STYLE.TOPMOST) else 0) | (if (o.ACCEPTFILES == 1) @intFromEnum(WINDOW_EX_STYLE.ACCEPTFILES) else 0) | (if (o.TRANSPARENT == 1) @intFromEnum(WINDOW_EX_STYLE.TRANSPARENT) else 0) | (if (o.MDICHILD == 1) @intFromEnum(WINDOW_EX_STYLE.MDICHILD) else 0) | (if (o.TOOLWINDOW == 1) @intFromEnum(WINDOW_EX_STYLE.TOOLWINDOW) else 0) | (if (o.WINDOWEDGE == 1) @intFromEnum(WINDOW_EX_STYLE.WINDOWEDGE) else 0) | (if (o.CLIENTEDGE == 1) @intFromEnum(WINDOW_EX_STYLE.CLIENTEDGE) else 0) | (if (o.CONTEXTHELP == 1) @intFromEnum(WINDOW_EX_STYLE.CONTEXTHELP) else 0) | (if (o.RIGHT == 1) @intFromEnum(WINDOW_EX_STYLE.RIGHT) else 0) | (if (o.LEFT == 1) @intFromEnum(WINDOW_EX_STYLE.LEFT) else 0) | (if (o.RTLREADING == 1) @intFromEnum(WINDOW_EX_STYLE.RTLREADING) else 0) | (if (o.LEFTSCROLLBAR == 1) @intFromEnum(WINDOW_EX_STYLE.LEFTSCROLLBAR) else 0) | (if (o.CONTROLPARENT == 1) @intFromEnum(WINDOW_EX_STYLE.CONTROLPARENT) else 0) | (if (o.STATICEDGE == 1) @intFromEnum(WINDOW_EX_STYLE.STATICEDGE) else 0) | (if (o.APPWINDOW == 1) @intFromEnum(WINDOW_EX_STYLE.APPWINDOW) else 0) | (if (o.OVERLAPPEDWINDOW == 1) @intFromEnum(WINDOW_EX_STYLE.OVERLAPPEDWINDOW) else 0) | (if (o.PALETTEWINDOW == 1) @intFromEnum(WINDOW_EX_STYLE.PALETTEWINDOW) else 0) | (if (o.LAYERED == 1) @intFromEnum(WINDOW_EX_STYLE.LAYERED) else 0) | (if (o.NOINHERITLAYOUT == 1) @intFromEnum(WINDOW_EX_STYLE.NOINHERITLAYOUT) else 0) | (if (o.NOREDIRECTIONBITMAP == 1) @intFromEnum(WINDOW_EX_STYLE.NOREDIRECTIONBITMAP) else 0) | (if (o.LAYOUTRTL == 1) @intFromEnum(WINDOW_EX_STYLE.LAYOUTRTL) else 0) | (if (o.COMPOSITED == 1) @intFromEnum(WINDOW_EX_STYLE.COMPOSITED) else 0) | (if (o.NOACTIVATE == 1) @intFromEnum(WINDOW_EX_STYLE.NOACTIVATE) else 0),
            ),
        );
    }
};
pub const WS_EX_DLGMODALFRAME: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.DLGMODALFRAME);
pub const WS_EX_NOPARENTNOTIFY: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.NOPARENTNOTIFY);
pub const WS_EX_TOPMOST: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.TOPMOST);
pub const WS_EX_ACCEPTFILES: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.ACCEPTFILES);
pub const WS_EX_TRANSPARENT: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.TRANSPARENT);
pub const WS_EX_MDICHILD: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.MDICHILD);
pub const WS_EX_TOOLWINDOW: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.TOOLWINDOW);
pub const WS_EX_WINDOWEDGE: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.WINDOWEDGE);
pub const WS_EX_CLIENTEDGE: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.CLIENTEDGE);
pub const WS_EX_CONTEXTHELP: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.CONTEXTHELP);
pub const WS_EX_RIGHT: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.RIGHT);
pub const WS_EX_LEFT: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.LEFT);
pub const WS_EX_RTLREADING: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.RTLREADING);
pub const WS_EX_LTRREADING: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.LEFT);
pub const WS_EX_LEFTSCROLLBAR: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.LEFTSCROLLBAR);
pub const WS_EX_RIGHTSCROLLBAR: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.LEFT);
pub const WS_EX_CONTROLPARENT: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.CONTROLPARENT);
pub const WS_EX_STATICEDGE: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.STATICEDGE);
pub const WS_EX_APPWINDOW: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.APPWINDOW);
pub const WS_EX_OVERLAPPEDWINDOW: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.OVERLAPPEDWINDOW);
pub const WS_EX_PALETTEWINDOW: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.PALETTEWINDOW);
pub const WS_EX_LAYERED: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.LAYERED);
pub const WS_EX_NOINHERITLAYOUT: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.NOINHERITLAYOUT);
pub const WS_EX_NOREDIRECTIONBITMAP: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.NOREDIRECTIONBITMAP);
pub const WS_EX_LAYOUTRTL: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.LAYOUTRTL);
pub const WS_EX_COMPOSITED: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.COMPOSITED);
pub const WS_EX_NOACTIVATE: windows.DWORD = @intFromEnum(WINDOW_EX_STYLE.NOACTIVATE);
