const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const ShaderModule = opaque {
    pub const Error = error{
        ShaderModuleUnsupportedSource,
        ShaderModuleFailedToGenerate,
        ShaderModuleFailedToCompile,
        ShaderModuleFailedToCreate,
    };

    pub const SourceType = enum {
        spirv,
        hlsl,
        dxil,
        lsl,
    };

    pub const CompilationStatus = enum(u32) {
        success = 0x00000000,
        err = 0x00000001,
        device_lost = 0x00000002,
        unknown = 0x00000003,
    };

    pub const CompilationMessageType = enum(u32) {
        err = 0x00000000,
        warning = 0x00000001,
        info = 0x00000002,
    };

    pub const CompilationMessage = struct {
        message: ?[]const u8 = null,
        type: CompilationMessageType,
        line_num: u64,
        line_pos: u64,
        offset: u64,
        length: u64,
        utf16_line_pos: u64,
        utf16_offset: u64,
        utf16_length: u64,
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
        code: []const u8,
        source_type: SourceType,
    };

    pub inline fn getCompilationStatus(sslf: *const ShaderModule) CompilationStatus {
        return impl.shaderModuleGetCompilationStatus(sslf);
    }

    pub inline fn getCompilationMessages(sslf: *const ShaderModule) ?[]const CompilationMessage {
        return impl.shaderModuleGetCompilationMessages(sslf);
    }

    pub inline fn destroy(self: *ShaderModule) void {
        impl.shaderModuleDestroy(self);
    }
};
