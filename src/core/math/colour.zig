const std = @import("std");
const builtin = @import("builtin");

pub const GammaSpace = enum(u8) {
    linear = 0,
    pow22 = 1,
    srgb = 2,
    invalid = 3,
};

pub const LinearColour = struct {
    pub const white = LinearColour.init(1.0, 1.0, 1.0);
    pub const gray = LinearColour.init(0.5, 0.5, 0.5);
    pub const black = LinearColour.init(0, 0, 0);
    pub const transparent = LinearColour.init(0, 0, 0, 0);
    pub const red = LinearColour.init(1.0, 0, 0);
    pub const green = LinearColour.init(0, 1.0, 0);
    pub const blue = LinearColour.init(0, 0, 1.0);
    pub const yellow = LinearColour.init(1.0, 1.0, 0);

    components: struct {
        r: f32,
        g: f32,
        b: f32,
        a: f32,
    },

    const pow_22_one_over_255_table: [256]f32 = [1]f32{0.0} ** 256;
    const srgb_to_linear_table: [256]f32 = [1]f32{0.0} ** 256;

    pub inline fn default() LinearColour {
        return LinearColour{ .components = .{
            .r = 0.0,
            .g = 0.0,
            .b = 0.0,
            .a = 0.0,
        } };
    }

    pub inline fn from_rgba(r: ?f32, g: ?f32, b: ?f32, a: ?f32) LinearColour {
        return LinearColour{ .components = .{
            .r = r orelse 1.0,
            .g = g orelse 1.0,
            .b = b orelse 1.0,
            .a = a orelse 1.0,
        } };
    }

    pub inline fn from_colour(colour: Colour) LinearColour {
        return LinearColour{ .components = .{
            .r = pow_22_one_over_255_table[colour.data.components.r],
            .g = pow_22_one_over_255_table[colour.data.components.g],
            .b = pow_22_one_over_255_table[colour.data.components.b],
            .a = @as(f32, @floatFromInt(colour.data.components.a)) * (1.0 / 255.0),
        } };
    }

    pub fn to_rgbe(self: LinearColour) Colour {
        const primary = @max(@max(self.components.r, self.components.g), self.components.b);

        if (primary <= 1e-32) {
            return Colour{ .data = .{ .components = .{ .r = 0, .g = 0, .b = 0, .a = 0 } } };
        } else {
            const non_negative_r = @max(0.0, self.components.r);
            const non_negative_g = @max(0.0, self.components.g);
            const non_negative_b = @max(0.0, self.components.b);

            var exponent = 1 + @as(i32, @bitCast(@log2(@fabs(primary))));
            const scale = std.math.ldexp(@as(f32, 1.0), -exponent + 8);

            const r = @as(u8, @min(255, @as(i32, @round(non_negative_r * scale))));
            const g = @as(u8, @min(255, @as(i32, @round(non_negative_g * scale))));
            const b = @as(u8, @min(255, @as(i32, @round(non_negative_b * scale))));
            const e = @as(u8, @min(255, @as(i32, exponent)));

            return Colour{ .data = .{ .components = .{ .r = r, .g = g, .b = b, .a = e } } };
        }
    }

    pub fn to_colour_srgb(self: LinearColour) Colour {
        return Colour{ .data = .{ .components = .{
            .r = stbir__linear_to_srgb_uchar_fast(self.components.r),
            .g = stbir__linear_to_srgb_uchar_fast(self.components.g),
            .b = stbir__linear_to_srgb_uchar_fast(self.components.b),
            .a = @bitCast(0.5 + std.math.clamp(self.components.a, 0.0, 1.0) * 255.0),
        } } };
    }

    pub fn convert_many_to_srgb(colours: []LinearColour) ColourConverterIterator {
        return ColourConverterIterator{ .colours = colours, .index = 0 };
    }

    const ColourConverterIterator = struct {
        colours: []LinearColour,
        index: usize,

        pub fn next(self: *ColourConverterIterator) ?Colour {
            if (self.index < self.colours.len) {
                const colour = self.colours[self.index];
                self.index += 1;
                return colour.to_colour_srgb();
            } else {
                return null;
            }
        }

        pub fn reset(self: *ColourConverterIterator) void {
            self.index = 0;
        }
    };

    pub fn luminance(self: LinearColour) f32 {
        return 0.3 * self.components.r + 0.59 * self.components.g + 0.11 * self.components.b;
    }

    pub fn desaturate(self: LinearColour, desaturation: f32) LinearColour {
        var lum = self.luminance();
        return LinearColour{
            .components = .{
                .r = std.math.lerp(self.components.r, lum, desaturation),
                .g = std.math.lerp(self.components.g, lum, desaturation),
                .b = std.math.lerp(self.components.b, lum, desaturation),
                .a = self.components.a,
            },
        };
    }
};

const stb_fp32_to_srgb8_tab4: [104]u32 = .{
    0x0073000d, 0x007a000d, 0x0080000d, 0x0087000d, 0x008d000d, 0x0094000d, 0x009a000d, 0x00a1000d,
    0x00a7001a, 0x00b4001a, 0x00c1001a, 0x00ce001a, 0x00da001a, 0x00e7001a, 0x00f4001a, 0x0101001a,
    0x010e0033, 0x01280033, 0x01410033, 0x015b0033, 0x01750033, 0x018f0033, 0x01a80033, 0x01c20033,
    0x01dc0067, 0x020f0067, 0x02430067, 0x02760067, 0x02aa0067, 0x02dd0067, 0x03110067, 0x03440067,
    0x037800ce, 0x03df00ce, 0x044600ce, 0x04ad00ce, 0x051400ce, 0x057b00c5, 0x05dd00bc, 0x063b00b5,
    0x06970158, 0x07420142, 0x07e30130, 0x087b0120, 0x090b0112, 0x09940106, 0x0a1700fc, 0x0a9500f2,
    0x0b0f01cb, 0x0bf401ae, 0x0ccb0195, 0x0d950180, 0x0e56016e, 0x0f0d015e, 0x0fbc0150, 0x10630143,
    0x11070264, 0x1238023e, 0x1357021d, 0x14660201, 0x156601e9, 0x165a01d3, 0x174401c0, 0x182401af,
    0x18fe0331, 0x1a9602fe, 0x1c1502d2, 0x1d7e02ad, 0x1ed4028d, 0x201a0270, 0x21520256, 0x227d0240,
    0x239f0443, 0x25c003fe, 0x27bf03c4, 0x29a10392, 0x2b6a0367, 0x2d1d0341, 0x2ebe031f, 0x304d0300,
    0x31d105b0, 0x34a80555, 0x37520507, 0x39d504c5, 0x3c37048b, 0x3e7c0458, 0x40a8042a, 0x42bd0401,
    0x44c20798, 0x488e071e, 0x4c1c06b6, 0x4f76065d, 0x52a50610, 0x55ac05cc, 0x5892058f, 0x5b590559,
    0x5e0c0a23, 0x631c0980, 0x67db08f6, 0x6c55087f, 0x70940818, 0x74a007bd, 0x787d076c, 0x7c330723,
};

const stbir__FP32 = union {
    u: u32,
    f: f32,
};

fn stbir__linear_to_srgb_uchar_fast(in: f32) u8 {
    const almost_one = stbir__FP32{ .u = 0x3f7fffff };
    const min_value = stbir__FP32{ .f = (127 - 13) << 23 };

    var f: stbir__FP32 = undefined;

    if (!(in > min_value.f)) {
        in = min_value.f;
    }
    if (in > almost_one.f) {
        in = almost_one.f;
    }

    f.f = in;
    const tab = stb_fp32_to_srgb8_tab4[(f.u - min_value.u) >> 20];
    const bias: u32 = (tab >> 16) << 9;
    const scale: u32 = tab & 0xffff;

    const t: u32 = (f.u >> 12) & 0xff;
    return @intCast((bias + scale * t) >> 16);
}

pub const Colour = struct {
    pub const white = Colour.init(255, 255, 255);
    pub const black = Colour.init(0, 0, 0);
    pub const transparent = Colour.init(0, 0, 0, 0);
    pub const red = Colour.init(255, 0, 0);
    pub const green = Colour.init(0, 255, 0);
    pub const blue = Colour.init(0, 0, 255);
    pub const yellow = Colour.init(255, 255, 0);
    pub const cyan = Colour.init(0, 255, 255);
    pub const magenta = Colour.init(255, 0, 255);
    pub const orange = Colour.init(243, 156, 18);
    pub const purple = Colour.init(169, 7, 228);
    pub const turquoise = Colour.init(26, 188, 156);
    pub const silver = Colour.init(189, 195, 199);
    pub const emerald = Colour.init(46, 204, 113);

    data: if (builtin.target.cpu.arch.endian() == .Little) union {
        components: struct {
            b: u8,
            g: u8,
            r: u8,
            a: u8,
        },
        bits: u32,
    } else union {
        components: struct {
            a: u8,
            r: u8,
            g: u8,
            b: u8,
        },
        bits: u32,
    },

    pub fn init(r: ?u8, g: ?u8, b: ?u8, a: ?u8) Colour {
        return Colour{ .data = .{ .components = .{
            .r = r orelse 255,
            .g = g orelse 255,
            .b = b orelse 255,
            .a = a orelse 255,
        } } };
    }

    pub fn from_rgbe(self: Colour) LinearColour {
        if (self.data.components.a == 0) {
            return LinearColour{ .components = .{
                .r = 0.0,
                .g = 0.0,
                .b = 0.0,
                .a = 0.0,
            } };
        } else {
            const exponent = @as(i32, self.components.a) - 128;
            const scale = std.math.ldexp(@as(f32, 1.0), exponent - (8 + 1));

            return LinearColour{ .components = .{
                .r = @as(f32, self.components.r) * scale,
                .g = @as(f32, self.components.g) * scale,
                .b = @as(f32, self.components.b) * scale,
                .a = 1.0,
            } };
        }
    }
};
