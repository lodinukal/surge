const std = @import("std");

const gpu = @import("../../gpu.zig");

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

pub fn dxgiFormatForTexture(format: gpu.Texture.Format) dxgi.common.DXGI_FORMAT {
    return switch (format) {
        .undefined => unreachable,
        .r8_unorm => .R8_UNORM,
        .r8_snorm => .R8_SNORM,
        .r8_uint => .R8_UINT,
        .r8_sint => .R8_SINT,
        .r16_uint => .R16_UINT,
        .r16_sint => .R16_SINT,
        .r16_float => .R16_FLOAT,
        .rg8_unorm => .R8G8_UNORM,
        .rg8_snorm => .R8G8_SNORM,
        .rg8_uint => .R8G8_UINT,
        .rg8_sint => .R8G8_SINT,
        .r32_float => .R32_FLOAT,
        .r32_uint => .R32_UINT,
        .r32_sint => .R32_SINT,
        .rg16_uint => .R16G16_UINT,
        .rg16_sint => .R16G16_SINT,
        .rg16_float => .R16G16_FLOAT,
        .rgba8_unorm => .R8G8B8A8_UNORM,
        .rgba8_unorm_srgb => .R8G8B8A8_UNORM_SRGB,
        .rgba8_snorm => .R8G8B8A8_SNORM,
        .rgba8_uint => .R8G8B8A8_UINT,
        .rgba8_sint => .R8G8B8A8_SINT,
        .bgra8_unorm => .B8G8R8A8_UNORM,
        .bgra8_unorm_srgb => .B8G8R8A8_UNORM_SRGB,
        .rgb10_a2_unorm => .R10G10B10A2_UNORM,
        .rg11_b10_ufloat => .R11G11B10_FLOAT,
        .rgb9_e5_ufloat => .R9G9B9E5_SHAREDEXP,
        .rg32_float => .R32G32_FLOAT,
        .rg32_uint => .R32G32_UINT,
        .rg32_sint => .R32G32_SINT,
        .rgba16_uint => .R16G16B16A16_UINT,
        .rgba16_sint => .R16G16B16A16_SINT,
        .rgba16_float => .R16G16B16A16_FLOAT,
        .rgba32_float => .R32G32B32A32_FLOAT,
        .rgba32_uint => .R32G32B32A32_UINT,
        .rgba32_sint => .R32G32B32A32_SINT,
        .stencil8 => .D24_UNORM_S8_UINT,
        .depth16_unorm => .D16_UNORM,
        .depth24_plus => .D24_UNORM_S8_UINT,
        .depth24_plus_stencil8 => .D24_UNORM_S8_UINT,
        .depth32_float => .D32_FLOAT,
        .depth32_float_stencil8 => .D32_FLOAT_S8X24_UINT,
        .bc1_rgba_unorm => .BC1_UNORM,
        .bc1_rgba_unorm_srgb => .BC1_UNORM_SRGB,
        .bc2_rgba_unorm => .BC2_UNORM,
        .bc2_rgba_unorm_srgb => .BC2_UNORM_SRGB,
        .bc3_rgba_unorm => .BC3_UNORM,
        .bc3_rgba_unorm_srgb => .BC3_UNORM_SRGB,
        .bc4_runorm => .BC4_UNORM,
        .bc4_rsnorm => .BC4_SNORM,
        .bc5_rg_unorm => .BC5_UNORM,
        .bc5_rg_snorm => .BC5_SNORM,
        .bc6_hrgb_ufloat => .BC6H_UF16,
        .bc6_hrgb_float => .BC6H_SF16,
        .bc7_rgba_unorm => .BC7_UNORM,
        .bc7_rgba_unorm_srgb => .BC7_UNORM_SRGB,
        .etc2_rgb8_unorm,
        .etc2_rgb8_unorm_srgb,
        .etc2_rgb8_a1_unorm,
        .etc2_rgb8_a1_unorm_srgb,
        .etc2_rgba8_unorm,
        .etc2_rgba8_unorm_srgb,
        .eacr11_unorm,
        .eacr11_snorm,
        .eacrg11_unorm,
        .eacrg11_snorm,
        .astc4x4_unorm,
        .astc4x4_unorm_srgb,
        .astc5x4_unorm,
        .astc5x4_unorm_srgb,
        .astc5x5_unorm,
        .astc5x5_unorm_srgb,
        .astc6x5_unorm,
        .astc6x5_unorm_srgb,
        .astc6x6_unorm,
        .astc6x6_unorm_srgb,
        .astc8x5_unorm,
        .astc8x5_unorm_srgb,
        .astc8x6_unorm,
        .astc8x6_unorm_srgb,
        .astc8x8_unorm,
        .astc8x8_unorm_srgb,
        .astc10x5_unorm,
        .astc10x5_unorm_srgb,
        .astc10x6_unorm,
        .astc10x6_unorm_srgb,
        .astc10x8_unorm,
        .astc10x8_unorm_srgb,
        .astc10x10_unorm,
        .astc10x10_unorm_srgb,
        .astc12x10_unorm,
        .astc12x10_unorm_srgb,
        .astc12x12_unorm,
        .astc12x12_unorm_srgb,
        => unreachable,
        .r8_bg8_biplanar420_unorm => .NV12,
    };
}

pub fn dxgiFormatTypeless(format: gpu.Texture.Format) dxgi.common.DXGI_FORMAT {
    return switch (format) {
        .undefined => unreachable,
        .r8_unorm, .r8_snorm, .r8_uint, .r8_sint => .R8_TYPELESS,
        .r16_uint, .r16_sint, .r16_float => .R16_TYPELESS,
        .rg8_unorm, .rg8_snorm, .rg8_uint, .rg8_sint => .R8G8_TYPELESS,
        .r32_float, .r32_uint, .r32_sint => .R32_TYPELESS,
        .rg16_uint, .rg16_sint, .rg16_float => .R16G16_TYPELESS,
        .rgba8_unorm, .rgba8_unorm_srgb, .rgba8_snorm, .rgba8_uint, .rgba8_sint => .R8G8B8A8_TYPELESS,
        .bgra8_unorm, .bgra8_unorm_srgb => .B8G8R8A8_TYPELESS,
        .rgb10_a2_unorm => .R10G10B10A2_TYPELESS,
        .rg11_b10_ufloat => .R11G11B10_FLOAT,
        .rgb9_e5_ufloat => .R9G9B9E5_SHAREDEXP,
        .rg32_float, .rg32_uint, .rg32_sint => .R32G32_TYPELESS,
        .rgba16_uint, .rgba16_sint, .rgba16_float => .R16G16B16A16_TYPELESS,
        .rgba32_float, .rgba32_uint, .rgba32_sint => .R32G32B32A32_TYPELESS,
        .stencil8 => .R24G8_TYPELESS,
        .depth16_unorm => .R16_TYPELESS,
        .depth24_plus => .R24G8_TYPELESS,
        .depth24_plus_stencil8 => .R24G8_TYPELESS,
        .depth32_float => .R32_TYPELESS,
        .depth32_float_stencil8 => .R32G8X24_TYPELESS,
        .bc1_rgba_unorm, .bc1_rgba_unorm_srgb => .BC1_TYPELESS,
        .bc2_rgba_unorm, .bc2_rgba_unorm_srgb => .BC2_TYPELESS,
        .bc3_rgba_unorm, .bc3_rgba_unorm_srgb => .BC3_TYPELESS,
        .bc4_runorm, .bc4_rsnorm => .BC4_TYPELESS,
        .bc5_rg_unorm, .bc5_rg_snorm => .BC5_TYPELESS,
        .bc6_hrgb_ufloat, .bc6_hrgb_float => .BC6H_TYPELESS,
        .bc7_rgba_unorm, .bc7_rgba_unorm_srgb => .BC7_TYPELESS,
        .etc2_rgb8_unorm,
        .etc2_rgb8_unorm_srgb,
        .etc2_rgb8_a1_unorm,
        .etc2_rgb8_a1_unorm_srgb,
        .etc2_rgba8_unorm,
        .etc2_rgba8_unorm_srgb,
        .eacr11_unorm,
        .eacr11_snorm,
        .eacrg11_unorm,
        .eacrg11_snorm,
        .astc4x4_unorm,
        .astc4x4_unorm_srgb,
        .astc5x4_unorm,
        .astc5x4_unorm_srgb,
        .astc5x5_unorm,
        .astc5x5_unorm_srgb,
        .astc6x5_unorm,
        .astc6x5_unorm_srgb,
        .astc6x6_unorm,
        .astc6x6_unorm_srgb,
        .astc8x5_unorm,
        .astc8x5_unorm_srgb,
        .astc8x6_unorm,
        .astc8x6_unorm_srgb,
        .astc8x8_unorm,
        .astc8x8_unorm_srgb,
        .astc10x5_unorm,
        .astc10x5_unorm_srgb,
        .astc10x6_unorm,
        .astc10x6_unorm_srgb,
        .astc10x8_unorm,
        .astc10x8_unorm_srgb,
        .astc10x10_unorm,
        .astc10x10_unorm_srgb,
        .astc12x10_unorm,
        .astc12x10_unorm_srgb,
        .astc12x12_unorm,
        .astc12x12_unorm_srgb,
        => unreachable,
        .r8_bg8_biplanar420_unorm => .NV12,
    };
}

pub fn dxgiFormatForTextureView(format: gpu.Texture.Format, aspect: gpu.Texture.Aspect) dxgi.common.DXGI_FORMAT {
    return switch (aspect) {
        .all => switch (format) {
            .stencil8 => .X24_TYPELESS_G8_UINT,
            .depth16_unorm => .R16_UNORM,
            .depth24_plus => .R24_UNORM_X8_TYPELESS,
            .depth32_float => .R32_FLOAT,
            else => dxgiFormatForTexture(format),
        },
        .stencil_only => switch (format) {
            .stencil8 => .X24_TYPELESS_G8_UINT,
            .depth24_plus_stencil8 => .X24_TYPELESS_G8_UINT,
            .depth32_float_stencil8 => .X32_TYPELESS_G8X24_UINT,
            else => unreachable,
        },
        .depth_only => switch (format) {
            .depth16_unorm => .R16_UNORM,
            .depth24_plus => .R24_UNORM_X8_TYPELESS,
            .depth24_plus_stencil8 => .R24_UNORM_X8_TYPELESS,
            .depth32_float => .R32_FLOAT,
            .depth32_float_stencil8 => .R32_FLOAT_X8X24_TYPELESS,
            else => unreachable,
        },
        .plane0_only => unreachable,
        .plane1_only => unreachable,
    };
}

pub fn dxgiFormatIsTypeless(format: dxgi.common.DXGI_FORMAT) bool {
    return switch (format) {
        .R32G32B32A32_TYPELESS,
        .R32G32B32_TYPELESS,
        .R16G16B16A16_TYPELESS,
        .R32G32_TYPELESS,
        .R32G8X24_TYPELESS,
        .R32_FLOAT_X8X24_TYPELESS,
        .R10G10B10A2_TYPELESS,
        .R8G8B8A8_TYPELESS,
        .R16G16_TYPELESS,
        .R32_TYPELESS,
        .R24G8_TYPELESS,
        .R8G8_TYPELESS,
        .R16_TYPELESS,
        .R8_TYPELESS,
        .BC1_TYPELESS,
        .BC2_TYPELESS,
        .BC3_TYPELESS,
        .BC4_TYPELESS,
        .BC5_TYPELESS,
        .B8G8R8A8_TYPELESS,
        .BC6H_TYPELESS,
        .BC7_TYPELESS,
        => true,
        else => false,
    };
}

pub fn dxgiFormatForVertex(format: gpu.VertexFormat) dxgi.common.DXGI_FORMAT {
    return switch (format) {
        .undefined => unreachable,
        .uint8x2 => .R8G8_UINT,
        .uint8x4 => .R8G8B8A8_UINT,
        .sint8x2 => .R8G8_SINT,
        .sint8x4 => .R8G8B8A8_SINT,
        .unorm8x2 => .R8G8_UNORM,
        .unorm8x4 => .R8G8B8A8_UNORM,
        .snorm8x2 => .R8G8_SNORM,
        .snorm8x4 => .R8G8B8A8_SNORM,
        .uint16x2 => .R16G16_UINT,
        .uint16x4 => .R16G16B16A16_UINT,
        .sint16x2 => .R16G16_SINT,
        .sint16x4 => .R16G16B16A16_SINT,
        .unorm16x2 => .R16G16_UNORM,
        .unorm16x4 => .R16G16B16A16_UNORM,
        .snorm16x2 => .R16G16_SNORM,
        .snorm16x4 => .R16G16B16A16_SNORM,
        .float16x2 => .R16G16_FLOAT,
        .float16x4 => .R16G16B16A16_FLOAT,
        .float32 => .R32_FLOAT,
        .float32x2 => .R32G32_FLOAT,
        .float32x3 => .R32G32B32_FLOAT,
        .float32x4 => .R32G32B32A32_FLOAT,
        .uint32 => .R32_UINT,
        .uint32x2 => .R32G32_UINT,
        .uint32x3 => .R32G32B32_UINT,
        .uint32x4 => .R32G32B32A32_UINT,
        .sint32 => .R32_SINT,
        .sint32x2 => .R32G32_SINT,
        .sint32x3 => .R32G32B32_SINT,
        .sint32x4 => .R32G32B32A32_SINT,
    };
}
