const std = @import("std");

const windows_platform = @import("windows.zig");

const win32 = @import("win32");
const common = @import("../../../core/common.zig");

const windows = @import("windows.zig");

const platform = @import("../platform_impl.zig");
const dpi = @import("../../dpi.zig");

const gdi = win32.graphics.gdi;
const foundation = win32.foundation;
const globalization = win32.globalization;
const wam = win32.ui.windows_and_messaging;
const hi_dpi = win32.ui.hi_dpi;
const ime = win32.ui.ime;
const z32 = win32.zig;

pub const ImeContext = struct {
    wnd: foundation.HWND,
    imc: globalization.HIMC,

    pub fn deinit(ic: *ImeContext) void {
        ime.ImmReleaseContext(ic.wnd, ic.imc);
    }

    pub fn current(wnd: foundation.HWND) ImeContext {
        const imc = ime.ImmGetContext(wnd);
        return ImeContext{ .wnd = wnd, .imc = imc };
    }

    pub fn getComposingTextAndCursor(ic: *const ImeContext, allocator: std.mem.Allocator) !?struct { []u8, ?usize, ?usize } {
        const text = try ic.getCompositionString(allocator, ime.GCS_COMPSTR) orelse return null;
        const attrs = try ic.getCompositionData(allocator, ime.GCS_COMPATTR) orelse
            allocator.dupe(u8, "");

        var first: ?usize = null;
        var last: ?usize = null;
        var boundary_before_char: usize = 0;

        var it = (try std.unicode.Utf8View.init(text)).iterator();
        for (attrs) |attr| {
            const char_is_targetted = @as(u32, attr) == ime.ATTR_TARGET_CONVERTED or
                @as(u32, attr) == ime.ATTR_TARGET_NOTCONVERTED;
            if (first == null and char_is_targetted) {
                first = boundary_before_char;
            } else if (first != null and last == null and !char_is_targetted) {
                last = boundary_before_char;
            }
            const cp_slice = it.nextCodepointSlice();
            if (cp_slice) |s| {
                boundary_before_char += utfLen(s);
            } else {
                break;
            }
        }

        if (first != null and last == null) {
            last = text.len;
        } else if (first == null) {
            const cursor = try ic.getCompositionCursor(text);
            first = cursor;
            last = cursor;
        }

        return .{ text, first, last };
    }

    pub fn getComposedText(ic: *const ImeContext) ?[]u8 {
        return ic.getCompositionString(ime.GCS_RESULTSTR);
    }

    pub fn getCompositionCursor(ic: *const ImeContext, text: []const u8) ?usize {
        const cursor = ime.ImmGetCompositionStringW(ic.imc, ime.GCS_CURSORPOS, null, 0);
        if (cursor < 0) {
            return;
        }
        var it = (try std.unicode.Utf8View.init(text)).iterator();
        var len: usize = 0;
        for (0..cursor) |_| {
            const cp_slice = it.nextCodepointSlice();
            if (cp_slice) |s| {
                len += try utfLen(s);
            } else {
                break;
            }
        }
        return len;
    }

    pub fn getCompositionString(ic: *const ImeContext, allocator: std.mem.Allocator, gcs_mode: u32) !?[]u8 {
        const data = try ic.getCompositionData(gcs_mode) orelse return null;
        return try std.unicode.utf16leToUtf8Alloc(allocator, std.mem.bytesAsSlice(u16, data));
    }

    pub fn getCompositionData(ic: *const ImeContext, allocator: std.mem.Allocator, gcs_mode: u32) !?[]u8 {
        const test_size = blk: {
            const found_size = ime.ImmGetCompositionStringW(ic.imc, gcs_mode, null, 0);
            if (found_size == 0) {
                return try allocator.alloc(u8, 0);
            } else if (found_size < 0) {
                return null;
            }
            break :blk found_size;
        };

        var buffer = std.ArrayList(u8).initCapacity(allocator, test_size);
        const size = ime.ImmGetCompositionStringW(ic.imc, gcs_mode, buffer.items.ptr, buffer.capacity);

        if (size < 0) {
            return null;
        } else {
            buffer.shrinkRetainingCapacity(size);
            return try buffer.toOwnedSlice();
        }
    }

    pub fn setImeCursorArea(ic: *const ImeContext, spot: dpi.Position, size: dpi.Size, scale_factor: f64) void {
        if (!ImeContext.systemHasIme()) {
            return;
        }

        const p = spot.toPhysical(scale_factor);
        const s = size.toPhysical(scale_factor);
        const rc_area = foundation.RECT{
            .left = p.x,
            .top = p.y,
            .right = p.x + s.width,
            .bottom = p.y - s.height,
        };
        const candidate_form = ime.CANDIDATEFORM{
            .dwIndex = 0,
            .dwStyle = ime.CFS_EXCLUDE,
            .ptCurrentPos = foundation.POINT{ p.x, p.y },
            .rcArea = rc_area,
        };

        ime.ImmSetCandidateWindow(ic.imc, &candidate_form);
    }

    pub fn setImeAllowed(wnd: foundation.HWND, allowed: bool) void {
        if (!ImeContext.systemHasIme()) {
            return;
        }

        ime.ImmAssociateContext(wnd, 0, if (allowed) ime.IACE_DEFAULT else ime.IACE_CHILDREN);
    }

    pub fn systemHasIme() bool {
        return wam.GetSystemMetrics(wam.SM_IMMENABLED) != z32.FALSE;
    }
};

fn utfLen(s: []const u8) !u3 {
    if (s.len > 0) {
        return try std.unicode.utf8ByteSequenceLength(s[0]);
    }
}
