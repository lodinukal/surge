const std = @import("std");
const common = @import("../core/common.zig");
const native_endian = @import("builtin").target.cpu.arch.endian();

pub const Alpha = enum(u8) {
    @"opaque" = 255,
    transparent = 0,
};

pub const PixelType = enum(u4) {
    unknown = 0,
    index1 = 1,
    index4 = 2,
    index8 = 3,
    packed8 = 4,
    packed16 = 5,
    packed32 = 6,
    arrayU8 = 7,
    arrayU16 = 8,
    arrayU32 = 9,
    arrayF16 = 10,
    arrayF32 = 11,
};

pub const BitmapOrder = enum(u2) {
    none = 0,
    @"4321" = 1,
    @"1234" = 2,
};

pub const PackedOrder = enum(u4) {
    none = 0,
    xrgb = 1,
    rgbx = 2,
    argb = 3,
    rgba = 4,
    xbgr = 5,
    bgrx = 6,
    abgr = 7,
    bgra = 8,
};

pub const ArrayOrder = enum(u2) {
    none = 0,
    rgb = 1,
    bgr = 2,
};

pub const PackedLayout = enum(u4) {
    none = 0,
    @"332" = 1,
    @"4444" = 2,
    @"1555" = 3,
    @"5551" = 4,
    @"565" = 5,
    @"8888" = 6,
    @"2101010" = 7,
    @"1010102" = 8,
};

pub const Format = packed struct(u24) {
    _type: PixelType,
    _order: u5,
    _layout: PackedLayout,
    _bits: u8,
    _bytes: u3,

    pub const OrderUnion = union(enum) { bitmap: BitmapOrder, pack: PackedOrder, array: ArrayOrder };

    pub inline fn init(
        _type: PixelType,
        _order: OrderUnion,
        _layout: PackedLayout,
        _bits: u8,
        _bytes: u3,
    ) Format {
        var self: Format = undefined;
        self._type = _type;
        self._order = blk: {
            switch (_order) {
                inline else => |e| {
                    break :blk @intFromEnum(e);
                },
            }
        };
        self._layout = _layout;
        self._bits = _bits;
        self._bytes = _bytes;
        return self;
    }

    pub inline fn unknown() Format {
        return .{
            ._type = PixelType.unknown,
            ._order = 0,
            ._layout = PackedLayout.none,
            ._bits = 0,
            ._bytes = 0,
        };
    }

    pub inline fn to(format: Format) u24 {
        return @as(u24, format);
    }

    pub inline fn @"type"(format: Format) PixelType {
        return format._type;
    }

    pub inline fn order(format: Format) OrderUnion {
        switch (format.type()) {
            PixelType.index1, PixelType.index4, PixelType.index8 => {
                return OrderUnion{ .bitmap = @as(BitmapOrder, @enumFromInt(format._order)) };
            },
            PixelType.packed8, PixelType.packed16, PixelType.packed32 => {
                return OrderUnion{ .pack = @as(PackedOrder, @enumFromInt(format._order)) };
            },
            PixelType.arrayU8, PixelType.arrayU16, PixelType.arrayU32, PixelType.arrayF16, PixelType.arrayF32 => {
                return OrderUnion{ .array = @as(ArrayOrder, @enumFromInt(format._order)) };
            },
            else => {},
        }
        unreachable;
    }

    pub inline fn layout(format: Format) PackedLayout {
        return format._layout;
    }

    pub inline fn bits(format: Format) u8 {
        return format._bits;
    }

    pub inline fn bytes(format: Format) u3 {
        return format._bytes;
    }

    pub inline fn isIndexed(format: Format) bool {
        switch (format._type) {
            PixelType.index1, PixelType.index4, PixelType.index8 => {
                return true;
            },
            else => {
                return false;
            },
        }
    }

    pub inline fn isPacked(format: Format) bool {
        switch (format._type) {
            PixelType.packed8, PixelType.packed16, PixelType.packed32 => {
                return true;
            },
            else => {
                return false;
            },
        }
    }

    pub inline fn isArray(format: Format) bool {
        switch (format._type) {
            PixelType.arrayU8, PixelType.arrayU16, PixelType.arrayU32, PixelType.arrayF16, PixelType.arrayF32 => {
                return true;
            },
            else => {
                return false;
            },
        }
    }

    pub inline fn isAlpha(format: Format) bool {
        switch (format.order()) {
            .pack => |ord| {
                switch (ord) {
                    PackedOrder.argb, PackedOrder.rgba, PackedOrder.abgr, PackedOrder.bgra => {
                        return true;
                    },
                    else => {},
                }
            },
            else => {},
        }
        return false;
    }

    pub inline fn getName(format: Format) []const u8 {
        inline for (@typeInfo(Formats).Struct.decls) |decl| {
            if (@field(Formats, decl.name).eql(format)) {
                return decl.name;
            }
        }
        return "";
    }

    pub const MasksError = error{UnknownPixelFormat};
    pub const MaskSet = struct {
        bits_per_pixel: u32,
        masks: [4]u32,
        pub fn isValid(set: MaskSet) bool {
            return set.bits_per_pixel != 0 and
                set.masks[0] != 0 and
                set.masks[1] != 0 and
                set.masks[2] != 0 and
                set.masks[3] != 0;
        }
    };
    pub fn getMasks(format: Format) MasksError!MaskSet {
        var val = MaskSet{
            .bits_per_pixel = if (format.bytes() <= 2) format.bits() else @as(
                u32,
                @intCast(format.bytes()),
            ) * 8,
            .masks = [4]u32{ 0, 0, 0, 0 },
        };

        if (format.eql(Formats.rgb24)) {
            switch (native_endian) {
                .Big => {
                    val.masks[0] = 0x00ff0000;
                    val.masks[1] = 0x0000ff00;
                    val.masks[2] = 0x000000ff;
                },
                .Little => {
                    val.masks[0] = 0x000000ff;
                    val.masks[1] = 0x0000ff00;
                    val.masks[2] = 0x00ff0000;
                },
            }
            return val;
        }

        // Only valid for these
        switch (format.type()) {
            .packed8, .packed16, .packed32 => {},
            else => return val,
        }

        var temp_masks = [4]u32{ 0, 0, 0, 0 };
        switch (format.layout()) {
            .@"332" => {
                temp_masks[0] = 0x00000000;
                temp_masks[1] = 0x000000E0;
                temp_masks[2] = 0x0000001C;
                temp_masks[3] = 0x00000003;
            },
            .@"4444" => {
                temp_masks[0] = 0x0000F000;
                temp_masks[1] = 0x00000F00;
                temp_masks[2] = 0x000000F0;
                temp_masks[3] = 0x0000000F;
            },
            .@"1555" => {
                temp_masks[0] = 0x00008000;
                temp_masks[1] = 0x00007C00;
                temp_masks[2] = 0x000003E0;
                temp_masks[3] = 0x0000001F;
            },
            .@"5551" => {
                temp_masks[0] = 0x0000F800;
                temp_masks[1] = 0x000007C0;
                temp_masks[2] = 0x0000003E;
                temp_masks[3] = 0x00000001;
            },
            .@"565" => {
                temp_masks[0] = 0x00000000;
                temp_masks[1] = 0x0000F800;
                temp_masks[2] = 0x000007E0;
                temp_masks[3] = 0x0000001F;
            },
            .@"8888" => {
                temp_masks[0] = 0xFF000000;
                temp_masks[1] = 0x00FF0000;
                temp_masks[2] = 0x0000FF00;
                temp_masks[3] = 0x000000FF;
            },
            .@"2101010" => {
                temp_masks[0] = 0xC0000000;
                temp_masks[1] = 0x3FF00000;
                temp_masks[2] = 0x000FFC00;
                temp_masks[3] = 0x000003FF;
            },
            .@"1010102" => {
                temp_masks[0] = 0xFFC00000;
                temp_masks[1] = 0x003FF000;
                temp_masks[2] = 0x00000FFC;
                temp_masks[3] = 0x00000003;
            },
            else => {
                return MasksError.UnknownPixelFormat;
            },
        }

        const packed_order: PackedOrder = blk: {
            switch (format.order()) {
                .pack => |packed_order| {
                    break :blk packed_order;
                },
                else => {
                    return MasksError.UnknownPixelFormat;
                },
            }
        };

        switch (packed_order) {
            .xrgb => {
                val.masks[0] = temp_masks[1];
                val.masks[1] = temp_masks[2];
                val.masks[2] = temp_masks[3];
                val.masks[3] = 0;
            },
            .rgbx => {
                val.masks[0] = temp_masks[0];
                val.masks[1] = temp_masks[1];
                val.masks[2] = temp_masks[2];
                val.masks[3] = 0;
            },
            .argb => {
                val.masks[0] = temp_masks[1];
                val.masks[1] = temp_masks[2];
                val.masks[2] = temp_masks[3];
                val.masks[3] = temp_masks[0];
            },
            .rgba => {
                val.masks[0] = temp_masks[0];
                val.masks[1] = temp_masks[1];
                val.masks[2] = temp_masks[2];
                val.masks[3] = temp_masks[3];
            },
            .xbgr => {
                val.masks[0] = temp_masks[3];
                val.masks[1] = temp_masks[2];
                val.masks[2] = temp_masks[1];
                val.masks[3] = 0;
            },
            .bgrx => {
                val.masks[0] = temp_masks[2];
                val.masks[1] = temp_masks[1];
                val.masks[2] = temp_masks[0];
                val.masks[3] = 0;
            },
            .bgra => {
                val.masks[0] = temp_masks[2];
                val.masks[1] = temp_masks[1];
                val.masks[2] = temp_masks[0];
                val.masks[3] = temp_masks[3];
            },
            .abgr => {
                val.masks[0] = temp_masks[3];
                val.masks[1] = temp_masks[2];
                val.masks[2] = temp_masks[1];
                val.masks[3] = temp_masks[0];
            },
            else => {
                return MasksError.UnknownPixelFormat;
            },
        }

        return val;
    }

    pub inline fn fromMasks(bits_per_pixel: u32, masks: [4]u32) Format {
        switch (bits_per_pixel) {
            1 => {
                return Formats.index1msb;
            },
            4 => {
                return Formats.index4msb;
            },
            8 => {
                if (masks[0] == 0xE0 and
                    masks[1] == 0x1C and
                    masks[2] == 0x03 and
                    masks[3] == 0x00)
                {
                    return Formats.rgb332;
                } else {
                    return Formats.index8;
                }
            },
            12 => {
                if (masks[0] == 0) {
                    return Formats.xrgb4444;
                }
                if (masks[0] == 0x0F00 and
                    masks[1] == 0x00F0 and
                    masks[2] == 0x000F and
                    masks[3] == 0x0000)
                {
                    return Formats.xrgb4444;
                }
                if (masks[0] == 0x000F and
                    masks[1] == 0x00F0 and
                    masks[2] == 0x0F00 and
                    masks[3] == 0x0000)
                {
                    return Formats.xbgr4444;
                }
            },
            15, 16 => {
                if (masks[0] == 0 and bits_per_pixel == 15) {
                    return Formats.xrgb1555;
                }
                if (masks[0] == 0) {
                    return Formats.rgb565;
                }
                if (masks[0] == 0x7C00 and
                    masks[1] == 0x03E0 and
                    masks[2] == 0x001F and
                    masks[3] == 0x0000)
                {
                    return Formats.xrgb1555;
                }
                if (masks[0] == 0x001F and
                    masks[1] == 0x03E0 and
                    masks[2] == 0x7C00 and
                    masks[3] == 0x0000)
                {
                    return Formats.xbgr1555;
                }
                if (masks[0] == 0x0F00 and
                    masks[1] == 0x00F0 and
                    masks[2] == 0x000F and
                    masks[3] == 0xF000)
                {
                    return Formats.argb4444;
                }
                if (masks[0] == 0xF000 and
                    masks[1] == 0x0F00 and
                    masks[2] == 0x00F0 and
                    masks[3] == 0x000F)
                {
                    return Formats.rgba4444;
                }
                if (masks[0] == 0x000F and
                    masks[1] == 0x00F0 and
                    masks[2] == 0x0F00 and
                    masks[3] == 0xF000)
                {
                    return Formats.abgr4444;
                }
                if (masks[0] == 0x00F0 and
                    masks[1] == 0x0F00 and
                    masks[2] == 0xF000 and
                    masks[3] == 0x000F)
                {
                    return Formats.bgra4444;
                }
                if (masks[0] == 0x7C00 and
                    masks[1] == 0x03E0 and
                    masks[2] == 0x001F and
                    masks[3] == 0x8000)
                {
                    return Formats.argb1555;
                }
                if (masks[0] == 0xF800 and
                    masks[1] == 0x07C0 and
                    masks[2] == 0x003E and
                    masks[3] == 0x0001)
                {
                    return Formats.rgba5551;
                }
                if (masks[0] == 0x001F and
                    masks[1] == 0x03E0 and
                    masks[2] == 0x7C00 and
                    masks[3] == 0x8000)
                {
                    return Formats.abgr1555;
                }
                if (masks[0] == 0x003E and
                    masks[1] == 0x07C0 and
                    masks[2] == 0xF800 and
                    masks[3] == 0x0001)
                {
                    return Formats.bgra5551;
                }
                if (masks[0] == 0xF800 and
                    masks[1] == 0x07E0 and
                    masks[2] == 0x001F and
                    masks[3] == 0x0000)
                {
                    return Formats.rgb565;
                }
                if (masks[0] == 0x001F and
                    masks[1] == 0x07E0 and
                    masks[2] == 0xF800 and
                    masks[3] == 0x0000)
                {
                    return Formats.bgr565;
                }
                if (masks[0] == 0x003F and
                    masks[1] == 0x07C0 and
                    masks[2] == 0xF800 and
                    masks[3] == 0x0000)
                {
                    // Technically this would be BGR556, but Witek says this works in bug 3158 */
                    // redun
                    return Formats.rgb565;
                }
            },
            24 => {
                switch (masks[0]) {
                    0, 0x00FF0000 => {
                        switch (native_endian) {
                            .Big => {
                                return Formats.rgb24;
                            },
                            .Little => {
                                return Formats.bgr24;
                            },
                        }
                    },
                    0x000000FF => {
                        switch (native_endian) {
                            .Big => {
                                return Formats.bgr24;
                            },
                            .Little => {
                                return Formats.rgb24;
                            },
                        }
                    },
                    else => {},
                }
            },
            32 => {
                if (masks[0] == 0) {
                    return Formats.xrgb8888;
                }
                if (masks[0] == 0x00FF0000 and
                    masks[1] == 0x0000FF00 and
                    masks[2] == 0x000000FF and
                    masks[3] == 0x00000000)
                {
                    return Formats.xrgb8888;
                }
                if (masks[0] == 0xFF000000 and
                    masks[1] == 0x00FF0000 and
                    masks[2] == 0x0000FF00 and
                    masks[3] == 0x00000000)
                {
                    return Formats.rgbx8888;
                }
                if (masks[0] == 0x000000FF and
                    masks[1] == 0x0000FF00 and
                    masks[2] == 0x00FF0000 and
                    masks[3] == 0x00000000)
                {
                    return Formats.xbgr8888;
                }
                if (masks[0] == 0x0000FF00 and
                    masks[1] == 0x00FF0000 and
                    masks[2] == 0xFF000000 and
                    masks[3] == 0x00000000)
                {
                    return Formats.bgrx8888;
                }
                if (masks[0] == 0x00FF0000 and
                    masks[1] == 0x0000FF00 and
                    masks[2] == 0x000000FF and
                    masks[3] == 0xFF000000)
                {
                    return Formats.argb8888;
                }
                if (masks[0] == 0xFF000000 and
                    masks[1] == 0x00FF0000 and
                    masks[2] == 0x0000FF00 and
                    masks[3] == 0x000000FF)
                {
                    return Formats.rgba8888;
                }
                if (masks[0] == 0x000000FF and
                    masks[1] == 0x0000FF00 and
                    masks[2] == 0x00FF0000 and
                    masks[3] == 0xFF000000)
                {
                    return Formats.abgr8888;
                }
                if (masks[0] == 0x0000FF00 and
                    masks[1] == 0x00FF0000 and
                    masks[2] == 0xFF000000 and
                    masks[3] == 0x000000FF)
                {
                    return Formats.bgra8888;
                }
                if (masks[0] == 0x3FF00000 and
                    masks[1] == 0x000FFC00 and
                    masks[2] == 0x000003FF and
                    masks[3] == 0xC0000000)
                {
                    return Formats.argb2101010;
                }
            },
            else => {},
        }
        return Formats.unknown;
    }

    pub inline fn eql(format: Format, other: Format) bool {
        return format._type == other._type and
            format._order == other._order and
            format._layout == other._layout and
            format._bits == other._bits and
            format._bytes == other._bytes;
    }
};

pub const Formats = struct {
    pub const unknown = Format.unknown();
    pub const index1lsb = Format.init(
        PixelType.index1,
        Format.OrderUnion{ .bitmap = BitmapOrder.@"4321" },
        PackedLayout.none,
        1,
        0,
    );
    pub const index1msb = Format.init(
        PixelType.index1,
        Format.OrderUnion{ .bitmap = BitmapOrder.@"1234" },
        PackedLayout.none,
        1,
        0,
    );
    pub const index4lsb = Format.init(
        PixelType.index4,
        Format.OrderUnion{ .bitmap = BitmapOrder.@"4321" },
        PackedLayout.none,
        4,
        0,
    );
    pub const index4msb = Format.init(
        PixelType.index4,
        Format.OrderUnion{ .bitmap = BitmapOrder.@"1234" },
        PackedLayout.none,
        4,
        0,
    );
    pub const index8 = Format.init(
        PixelType.index8,
        Format.OrderUnion{ .bitmap = BitmapOrder.none },
        PackedLayout.none,
        8,
        1,
    );
    pub const rgb332 = Format.init(
        PixelType.packed8,
        Format.OrderUnion{ .pack = PackedOrder.xrgb },
        PackedLayout.@"332",
        8,
        1,
    );
    pub const xrgb4444 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.xrgb },
        PackedLayout.@"4444",
        12,
        2,
    );
    pub const xbgr4444 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.xbgr },
        PackedLayout.@"4444",
        12,
        2,
    );
    pub const xrgb1555 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.xrgb },
        PackedLayout.@"1555",
        15,
        2,
    );
    pub const xbgr1555 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.xbgr },
        PackedLayout.@"1555",
        15,
        2,
    );
    pub const argb4444 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.argb },
        PackedLayout.@"4444",
        16,
        2,
    );
    pub const rgba4444 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.rgba },
        PackedLayout.@"4444",
        16,
        2,
    );
    pub const abgr4444 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.abgr },
        PackedLayout.@"4444",
        16,
        2,
    );
    pub const bgra4444 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.bgra },
        PackedLayout.@"4444",
        16,
        2,
    );
    pub const argb1555 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.argb },
        PackedLayout.@"1555",
        16,
        2,
    );
    pub const rgba5551 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.rgba },
        PackedLayout.@"5551",
        16,
        2,
    );
    pub const abgr1555 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.abgr },
        PackedLayout.@"1555",
        16,
        2,
    );
    pub const bgra5551 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.bgra },
        PackedLayout.@"5551",
        16,
        2,
    );
    pub const rgb565 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.xrgb },
        PackedLayout.@"565",
        16,
        2,
    );
    pub const bgr565 = Format.init(
        PixelType.packed16,
        Format.OrderUnion{ .pack = PackedOrder.xbgr },
        PackedLayout.@"565",
        16,
        2,
    );
    pub const rgb24 = Format.init(
        PixelType.arrayU8,
        Format.OrderUnion{ .array = ArrayOrder.rgb },
        PackedLayout.none,
        24,
        3,
    );
    pub const bgr24 = Format.init(
        PixelType.arrayU8,
        Format.OrderUnion{ .array = ArrayOrder.bgr },
        PackedLayout.none,
        24,
        3,
    );
    pub const xrgb8888 = Format.init(
        PixelType.packed32,
        Format.OrderUnion{ .pack = PackedOrder.xrgb },
        PackedLayout.@"8888",
        24,
        4,
    );
    pub const rgbx8888 = Format.init(
        PixelType.packed32,
        Format.OrderUnion{ .pack = PackedOrder.rgbx },
        PackedLayout.@"8888",
        24,
        4,
    );
    pub const xbgr8888 = Format.init(
        PixelType.packed32,
        Format.OrderUnion{ .pack = PackedOrder.xbgr },
        PackedLayout.@"8888",
        24,
        4,
    );
    pub const bgrx8888 = Format.init(
        PixelType.packed32,
        Format.OrderUnion{ .pack = PackedOrder.bgrx },
        PackedLayout.@"8888",
        24,
        4,
    );
    pub const argb8888 = Format.init(
        PixelType.packed32,
        Format.OrderUnion{ .pack = PackedOrder.argb },
        PackedLayout.@"8888",
        32,
        4,
    );
    pub const rgba8888 = Format.init(
        PixelType.packed32,
        Format.OrderUnion{ .pack = PackedOrder.rgba },
        PackedLayout.@"8888",
        32,
        4,
    );
    pub const abgr8888 = Format.init(
        PixelType.packed32,
        Format.OrderUnion{ .pack = PackedOrder.abgr },
        PackedLayout.@"8888",
        32,
        4,
    );
    pub const bgra8888 = Format.init(
        PixelType.packed32,
        Format.OrderUnion{ .pack = PackedOrder.bgra },
        PackedLayout.@"8888",
        32,
        4,
    );
    pub const argb2101010 = Format.init(
        PixelType.packed32,
        Format.OrderUnion{ .pack = PackedOrder.argb },
        PackedLayout.@"2101010",
        32,
        4,
    );
};

pub const Color = packed struct(u32) {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

var formats_lock = std.Thread.Mutex{};
var formats: std.AutoArrayHashMap(Format, *PixelFormat) = undefined;

pub const PixelFormat = struct {
    format: Format,
    bits_per_pixel: u32,
    bytes_per_pixel: u8,
    padding: [2]u8,
    masks: [4]u32,
    losses: [4]u8,
    shifts: [4]u8,
    refcount: u32,

    pub fn fromFormat(allocator: std.mem.Allocator, format: Format) !*PixelFormat {
        formats_lock.lock();
        defer formats_lock.unlock();

        var found_pixel_format: ?*PixelFormat = formats.get(format);
        if (found_pixel_format) |pixel_format| {
            pixel_format.refcount += 1;
            return pixel_format;
        }

        var pixel_format: *PixelFormat = try allocator.create(PixelFormat);
        try pixel_format.init(format);

        if (!format.isIndexed()) {
            _ = try formats.put(format, pixel_format);
        }

        return pixel_format;
    }

    pub fn init(pixel_format: *PixelFormat, format: Format) !void {
        const masks = try format.getMasks();

        pixel_format.format = format;
        pixel_format.bits_per_pixel = masks.bits_per_pixel;
        pixel_format.bytes_per_pixel = @intCast(@divTrunc(masks.bits_per_pixel + 7, 8));
        pixel_format.masks = masks.masks;
        for (&pixel_format.masks, &pixel_format.losses, &pixel_format.shifts) |mask, *loss, *shift| {
            loss.* = 8;
            shift.* = 0;
            if (mask == 0) {
                continue;
            }
            // how much we have to shift so that it becomes 0
            shift.* = @intCast(@clz(mask));
            // how much we have to shift so that it become non zero
            var mask_mod = mask;
            while ((mask_mod & 0x1) > 1) {
                loss.* -= 1;
                mask_mod >>= 1;
            }
        }
        pixel_format.refcount = 1;
    }

    pub inline fn deinit(pixel_format: *PixelFormat, allocator: std.mem.Allocator) void {
        formats_lock.lock();
        defer formats_lock.unlock();

        pixel_format.refcount -= 1;
        if (pixel_format.refcount > 0) {
            return;
        }

        _ = formats.swapRemove(pixel_format.format);
        allocator.destroy(pixel_format);
    }

    // TODO: Mapping
    pub inline fn mapRGB(pixel_format: *const PixelFormat, r: u8, g: u8, b: u8) u32 {
        _ = pixel_format;
        _ = r;
        _ = g;
        _ = b;
        return 0;
    }

    pub inline fn mapRGBA(pixel_format: *const PixelFormat, r: u8, g: u8, b: u8, a: u8) u32 {
        _ = pixel_format;
        _ = r;
        _ = g;
        _ = b;
        _ = a;
        return 0;
    }

    pub inline fn getRGB(pixel_format: *const PixelFormat, pixel: u32) struct { u8, u8, u8 } {
        _ = pixel_format;
        _ = pixel;
        return .{ 0, 0, 0 };
    }

    pub inline fn getRGBA(pixel_format: *const PixelFormat, pixel: u32) struct { u8, u8, u8, u8 } {
        _ = pixel_format;
        _ = pixel;
        return .{ 0, 0, 0, 0 };
    }
};

pub fn init(allocator: std.mem.Allocator) !void {
    formats = std.AutoArrayHashMap(Format, *PixelFormat).init(allocator);
}

pub fn deinit() void {
    formats.deinit();
}

test "ref" {
    std.testing.refAllDeclsRecursive(@This());
}

test "getName" {
    @setEvalBranchQuota(3000);
    inline for (@typeInfo(Formats).Struct.decls) |decl| {
        var format = @field(Formats, decl.name);
        try std.testing.expectEqualStrings(
            decl.name,
            format.getName(),
        );
    }
}

test "masks" {
    @setEvalBranchQuota(3000);
    inline for (@typeInfo(Formats).Struct.decls) |decl| {
        comptime var format: Format = @field(Formats, decl.name);
        if (format.getMasks() catch null) |masks| {
            if (masks.isValid()) {
                try std.testing.expectEqualDeep(
                    format,
                    Format.fromMasks(masks.bits_per_pixel, masks.masks),
                );
            }
        }
    }
}

test "pixel_format" {
    var allocator = std.testing.allocator;

    try init(allocator);
    defer deinit();

    var pixel_format: *PixelFormat = try PixelFormat.fromFormat(allocator, Formats.xbgr4444);
    defer PixelFormat.deinit(pixel_format, allocator);
}
