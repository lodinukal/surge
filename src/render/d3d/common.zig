const std = @import("std");

const gpu = @import("../gpu.zig");

const winapi = @import("win32");
const win32 = winapi.windows.win32;

const d3d = win32.graphics.direct3d;
const d3d11 = win32.graphics.direct3d11;
const dxgi = win32.graphics.dxgi;
const hlsl = win32.graphics.hlsl;

pub fn releaseIUnknown(comptime T: type, obj: ?*?*T) void {
    if (obj) |o| {
        if (o.*) |unwrapped| {
            if (unwrapped.IUnknown_Release() == 0) {
                o.* = null;
            }
        }
    }
}

pub fn refIUnknown(comptime T: type, obj: ?*?*T) void {
    if (obj) |o| {
        if (o.*) |unwrapped| {
            unwrapped.IUnknown_AddRef();
        }
    }
}

pub fn checkHResult(hr: win32.foundation.HRESULT) bool {
    const failed = winapi.zig.FAILED(hr);
    if (failed) {
        std.log.warn("failed hr: {}", .{hr});
        if (@errorReturnTrace()) |trace| {
            std.log.warn("{}", .{trace});
        }
        @panic("failed hr");
    }

    return failed == false;
}

// mapping functions
pub inline fn mapPowerPreference(pref: gpu.PhysicalDevice.PowerPreference) dxgi.DXGI_GPU_PREFERENCE {
    return switch (pref) {
        .undefined => .UNSPECIFIED,
        .low_power => .MINIMUM_POWER,
        .high_performance => .HIGH_PERFORMANCE,
    };
}

pub const DxgiFormatMapping = struct {
    abstract: gpu.Format,
    resource: dxgi.common.DXGI_FORMAT,
    srv: dxgi.common.DXGI_FORMAT,
    uav: dxgi.common.DXGI_FORMAT,
};

const format_map = std.enums.directEnumArray(gpu.Format, DxgiFormatMapping, 0, .{
    .unknown = .{
        .abstract = .unknown,
        .resource = .UNKNOWN,
        .srv = .UNKNOWN,
        .uav = .UNKNOWN,
    },

    .r8_uint = .{
        .abstract = .r8_uint,
        .resource = .R8_TYPELESS,
        .srv = .R8_UINT,
        .uav = .R8_UINT,
    },
    .r8_sint = .{
        .abstract = .r8_sint,
        .resource = .R8_TYPELESS,
        .srv = .R8_SINT,
        .uav = .R8_SINT,
    },
    .r8_unorm = .{
        .abstract = .r8_unorm,
        .resource = .R8_TYPELESS,
        .srv = .R8_UNORM,
        .uav = .R8_UNORM,
    },
    .r8_snorm = .{
        .abstract = .r8_snorm,
        .resource = .R8_TYPELESS,
        .srv = .R8_SNORM,
        .uav = .R8_SNORM,
    },
    .rg8_uint = .{
        .abstract = .rg8_uint,
        .resource = .R8G8_TYPELESS,
        .srv = .R8G8_UINT,
        .uav = .R8G8_UINT,
    },
    .rg8_sint = .{
        .abstract = .rg8_sint,
        .resource = .R8G8_TYPELESS,
        .srv = .R8G8_SINT,
        .uav = .R8G8_SINT,
    },
    .rg8_unorm = .{
        .abstract = .rg8_unorm,
        .resource = .R8G8_TYPELESS,
        .srv = .R8G8_UNORM,
        .uav = .R8G8_UNORM,
    },
    .rg8_snorm = .{
        .abstract = .rg8_snorm,
        .resource = .R8G8_TYPELESS,
        .srv = .R8G8_SNORM,
        .uav = .R8G8_SNORM,
    },
    .r16_uint = .{
        .abstract = .r16_uint,
        .resource = .R16_TYPELESS,
        .srv = .R16_UINT,
        .uav = .R16_UINT,
    },
    .r16_sint = .{
        .abstract = .r16_sint,
        .resource = .R16_TYPELESS,
        .srv = .R16_SINT,
        .uav = .R16_SINT,
    },
    .r16_unorm = .{
        .abstract = .r16_unorm,
        .resource = .R16_TYPELESS,
        .srv = .R16_UNORM,
        .uav = .R16_UNORM,
    },
    .r16_snorm = .{
        .abstract = .r16_snorm,
        .resource = .R16_TYPELESS,
        .srv = .R16_SNORM,
        .uav = .R16_SNORM,
    },
    .r16_float = .{
        .abstract = .r16_float,
        .resource = .R16_TYPELESS,
        .srv = .R16_FLOAT,
        .uav = .R16_FLOAT,
    },
    .bgra4_unorm = .{
        .abstract = .bgra4_unorm,
        .resource = .B4G4R4A4_UNORM,
        .srv = .B4G4R4A4_UNORM,
        .uav = .B4G4R4A4_UNORM,
    },
    .b5g6r5_unorm = .{
        .abstract = .b5g6r5_unorm,
        .resource = .B5G6R5_UNORM,
        .srv = .B5G6R5_UNORM,
        .uav = .B5G6R5_UNORM,
    },
    .b5g5r5a1_unorm = .{
        .abstract = .b5g5r5a1_unorm,
        .resource = .B5G5R5A1_UNORM,
        .srv = .B5G5R5A1_UNORM,
        .uav = .B5G5R5A1_UNORM,
    },
    .rgba8_uint = .{
        .abstract = .rgba8_uint,
        .resource = .R8G8B8A8_TYPELESS,
        .srv = .R8G8B8A8_UINT,
        .uav = .R8G8B8A8_UINT,
    },
    .rgba8_sint = .{
        .abstract = .rgba8_sint,
        .resource = .R8G8B8A8_TYPELESS,
        .srv = .R8G8B8A8_SINT,
        .uav = .R8G8B8A8_SINT,
    },
    .rgba8_unorm = .{
        .abstract = .rgba8_unorm,
        .resource = .R8G8B8A8_TYPELESS,
        .srv = .R8G8B8A8_UNORM,
        .uav = .R8G8B8A8_UNORM,
    },
    .rgba8_snorm = .{
        .abstract = .rgba8_snorm,
        .resource = .R8G8B8A8_TYPELESS,
        .srv = .R8G8B8A8_SNORM,
        .uav = .R8G8B8A8_SNORM,
    },
    .bgra8_unorm = .{
        .abstract = .bgra8_unorm,
        .resource = .B8G8R8A8_TYPELESS,
        .srv = .B8G8R8A8_UNORM,
        .uav = .B8G8R8A8_UNORM,
    },
    .srgba8_unorm = .{
        .abstract = .srgba8_unorm,
        .resource = .R8G8B8A8_TYPELESS,
        .srv = .R8G8B8A8_UNORM_SRGB,
        .uav = .R8G8B8A8_UNORM_SRGB,
    },
    .sbgra8_unorm = .{
        .abstract = .sbgra8_unorm,
        .resource = .B8G8R8A8_TYPELESS,
        .srv = .B8G8R8A8_UNORM_SRGB,
        .uav = .B8G8R8A8_UNORM_SRGB,
    },
    .r10g10b10a2_unorm = .{
        .abstract = .r10g10b10a2_unorm,
        .resource = .R10G10B10A2_TYPELESS,
        .srv = .R10G10B10A2_UNORM,
        .uav = .R10G10B10A2_UNORM,
    },
    .r11g11b10_float = .{
        .abstract = .r11g11b10_float,
        .resource = .R11G11B10_FLOAT,
        .srv = .R11G11B10_FLOAT,
        .uav = .R11G11B10_FLOAT,
    },
    .rg16_uint = .{
        .abstract = .rg16_uint,
        .resource = .R16G16_TYPELESS,
        .srv = .R16G16_UINT,
        .uav = .R16G16_UINT,
    },
    .rg16_sint = .{
        .abstract = .rg16_sint,
        .resource = .R16G16_TYPELESS,
        .srv = .R16G16_SINT,
        .uav = .R16G16_SINT,
    },
    .rg16_unorm = .{
        .abstract = .rg16_unorm,
        .resource = .R16G16_TYPELESS,
        .srv = .R16G16_UNORM,
        .uav = .R16G16_UNORM,
    },
    .rg16_snorm = .{
        .abstract = .rg16_snorm,
        .resource = .R16G16_TYPELESS,
        .srv = .R16G16_SNORM,
        .uav = .R16G16_SNORM,
    },
    .rg16_float = .{
        .abstract = .rg16_float,
        .resource = .R16G16_TYPELESS,
        .srv = .R16G16_FLOAT,
        .uav = .R16G16_FLOAT,
    },
    .r32_uint = .{
        .abstract = .r32_uint,
        .resource = .R32_TYPELESS,
        .srv = .R32_UINT,
        .uav = .R32_UINT,
    },
    .r32_sint = .{
        .abstract = .r32_sint,
        .resource = .R32_TYPELESS,
        .srv = .R32_SINT,
        .uav = .R32_SINT,
    },
    .r32_float = .{
        .abstract = .r32_float,
        .resource = .R32_TYPELESS,
        .srv = .R32_FLOAT,
        .uav = .R32_FLOAT,
    },
    .rgba16_uint = .{
        .abstract = .rgba16_uint,
        .resource = .R16G16B16A16_TYPELESS,
        .srv = .R16G16B16A16_UINT,
        .uav = .R16G16B16A16_UINT,
    },
    .rgba16_sint = .{
        .abstract = .rgba16_sint,
        .resource = .R16G16B16A16_TYPELESS,
        .srv = .R16G16B16A16_SINT,
        .uav = .R16G16B16A16_SINT,
    },
    .rgba16_float = .{
        .abstract = .rgba16_float,
        .resource = .R16G16B16A16_TYPELESS,
        .srv = .R16G16B16A16_FLOAT,
        .uav = .R16G16B16A16_FLOAT,
    },
    .rgba16_unorm = .{
        .abstract = .rgba16_unorm,
        .resource = .R16G16B16A16_TYPELESS,
        .srv = .R16G16B16A16_UNORM,
        .uav = .R16G16B16A16_UNORM,
    },
    .rgba16_snorm = .{
        .abstract = .rgba16_snorm,
        .resource = .R16G16B16A16_TYPELESS,
        .srv = .R16G16B16A16_SNORM,
        .uav = .R16G16B16A16_SNORM,
    },
    .rg32_uint = .{
        .abstract = .rg32_uint,
        .resource = .R32G32_TYPELESS,
        .srv = .R32G32_UINT,
        .uav = .R32G32_UINT,
    },
    .rg32_sint = .{
        .abstract = .rg32_sint,
        .resource = .R32G32_TYPELESS,
        .srv = .R32G32_SINT,
        .uav = .R32G32_SINT,
    },
    .rg32_float = .{
        .abstract = .rg32_float,
        .resource = .R32G32_TYPELESS,
        .srv = .R32G32_FLOAT,
        .uav = .R32G32_FLOAT,
    },
    .rgb32_uint = .{
        .abstract = .rgb32_uint,
        .resource = .R32G32B32_TYPELESS,
        .srv = .R32G32B32_UINT,
        .uav = .R32G32B32_UINT,
    },
    .rgb32_sint = .{
        .abstract = .rgb32_sint,
        .resource = .R32G32B32_TYPELESS,
        .srv = .R32G32B32_SINT,
        .uav = .R32G32B32_SINT,
    },
    .rgb32_float = .{
        .abstract = .rgb32_float,
        .resource = .R32G32B32_TYPELESS,
        .srv = .R32G32B32_FLOAT,
        .uav = .R32G32B32_FLOAT,
    },
    .rgba32_uint = .{
        .abstract = .rgba32_uint,
        .resource = .R32G32B32A32_TYPELESS,
        .srv = .R32G32B32A32_UINT,
        .uav = .R32G32B32A32_UINT,
    },
    .rgba32_sint = .{
        .abstract = .rgba32_sint,
        .resource = .R32G32B32A32_TYPELESS,
        .srv = .R32G32B32A32_SINT,
        .uav = .R32G32B32A32_SINT,
    },
    .rgba32_float = .{
        .abstract = .rgba32_float,
        .resource = .R32G32B32A32_TYPELESS,
        .srv = .R32G32B32A32_FLOAT,
        .uav = .R32G32B32A32_FLOAT,
    },

    .d16 = .{
        .abstract = .d16,
        .resource = .R16_TYPELESS,
        .srv = .R16_UNORM,
        .uav = .D16_UNORM,
    },
    .d24s8 = .{
        .abstract = .d24s8,
        .resource = .R24G8_TYPELESS,
        .srv = .R24_UNORM_X8_TYPELESS,
        .uav = .D24_UNORM_S8_UINT,
    },
    .x24g8_uint = .{
        .abstract = .x24g8_uint,
        .resource = .R24G8_TYPELESS,
        .srv = .X24_TYPELESS_G8_UINT,
        .uav = .D24_UNORM_S8_UINT,
    },
    .d32 = .{
        .abstract = .d32,
        .resource = .R32_TYPELESS,
        .srv = .R32_FLOAT,
        .uav = .D32_FLOAT,
    },
    .d32s8 = .{
        .abstract = .d32s8,
        .resource = .R32G8X24_TYPELESS,
        .srv = .R32_FLOAT_X8X24_TYPELESS,
        .uav = .D32_FLOAT_S8X24_UINT,
    },
    .x32g8_uint = .{
        .abstract = .x32g8_uint,
        .resource = .R32G8X24_TYPELESS,
        .srv = .X32_TYPELESS_G8X24_UINT,
        .uav = .D32_FLOAT_S8X24_UINT,
    },

    .bc1_unorm = .{
        .abstract = .bc1_unorm,
        .resource = .BC1_TYPELESS,
        .srv = .BC1_UNORM,
        .uav = .BC1_UNORM,
    },
    .bc1_unorm_srgb = .{
        .abstract = .bc1_unorm_srgb,
        .resource = .BC1_TYPELESS,
        .srv = .BC1_UNORM_SRGB,
        .uav = .BC1_UNORM_SRGB,
    },
    .bc2_unorm = .{
        .abstract = .bc2_unorm,
        .resource = .BC2_TYPELESS,
        .srv = .BC2_UNORM,
        .uav = .BC2_UNORM,
    },
    .bc2_unorm_srgb = .{
        .abstract = .bc2_unorm_srgb,
        .resource = .BC2_TYPELESS,
        .srv = .BC2_UNORM_SRGB,
        .uav = .BC2_UNORM_SRGB,
    },
    .bc3_unorm = .{
        .abstract = .bc3_unorm,
        .resource = .BC3_TYPELESS,
        .srv = .BC3_UNORM,
        .uav = .BC3_UNORM,
    },
    .bc3_unorm_srgb = .{
        .abstract = .bc3_unorm_srgb,
        .resource = .BC3_TYPELESS,
        .srv = .BC3_UNORM_SRGB,
        .uav = .BC3_UNORM_SRGB,
    },
    .bc4_unorm = .{
        .abstract = .bc4_unorm,
        .resource = .BC4_TYPELESS,
        .srv = .BC4_UNORM,
        .uav = .BC4_UNORM,
    },
    .bc4_snorm = .{
        .abstract = .bc4_snorm,
        .resource = .BC4_TYPELESS,
        .srv = .BC4_SNORM,
        .uav = .BC4_SNORM,
    },
    .bc5_unorm = .{
        .abstract = .bc5_unorm,
        .resource = .BC5_TYPELESS,
        .srv = .BC5_UNORM,
        .uav = .BC5_UNORM,
    },
    .bc5_snorm = .{
        .abstract = .bc5_snorm,
        .resource = .BC5_TYPELESS,
        .srv = .BC5_SNORM,
        .uav = .BC5_SNORM,
    },
    .bc6h_ufloat = .{
        .abstract = .bc6h_ufloat,
        .resource = .BC6H_TYPELESS,
        .srv = .BC6H_UF16,
        .uav = .BC6H_UF16,
    },
    .bc6h_sfloat = .{
        .abstract = .bc6h_sfloat,
        .resource = .BC6H_TYPELESS,
        .srv = .BC6H_SF16,
        .uav = .BC6H_SF16,
    },
    .bc7_unorm = .{
        .abstract = .bc7_unorm,
        .resource = .BC7_TYPELESS,
        .srv = .BC7_UNORM,
        .uav = .BC7_UNORM,
    },
    .bc7_unorm_srgb = .{
        .abstract = .bc7_unorm_srgb,
        .resource = .BC7_TYPELESS,
        .srv = .BC7_UNORM_SRGB,
        .uav = .BC7_UNORM_SRGB,
    },
});
pub fn convertFormat(format: gpu.Format) dxgi.common.DXGI_FORMAT {
    return format_map[@intFromEnum(format)].resource;
}
