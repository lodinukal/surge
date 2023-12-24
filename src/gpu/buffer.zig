const std = @import("std");

const gpu = @import("gpu.zig");
const impl = gpu.impl;

pub const Buffer = opaque {
    pub const Error = error{
        BufferFailedToCreate,
        BufferSizeTooLarge,
        BufferMapAtCreationFailed,
        BufferAlreadyMapped,
        BufferNotMappable,
        BufferInvalidMapAccess,
        BufferMapFailed,
        BufferNotMapped,
    };

    pub const BindingType = enum(u32) {
        undefined = 0x00000000,
        uniform = 0x00000001,
        storage = 0x00000002,
        read_only_storage = 0x00000003,
    };

    pub const MapState = enum(u32) {
        unmapped = 0x00000000,
        pending = 0x00000001,
        mapped = 0x00000002,
    };

    pub const MapAsyncStatus = enum(u32) {
        success = 0x00000000,
        validation_error = 0x00000001,
        unknown = 0x00000002,
        device_lost = 0x00000003,
        destroyed_before_callback = 0x00000004,
        unmapped_before_callback = 0x00000005,
        mapping_already_pending = 0x00000006,
        offset_out_of_range = 0x00000007,
        size_out_of_range = 0x00000008,
    };

    pub const UsageFlags = packed struct(u32) {
        map_read: bool = false,
        map_write: bool = false,
        copy_src: bool = false,
        copy_dst: bool = false,
        index: bool = false,
        vertex: bool = false,
        uniform: bool = false,
        storage: bool = false,
        indirect: bool = false,
        query_resolve: bool = false,

        _padding: u22 = 0,

        comptime {
            std.debug.assert(
                @sizeOf(@This()) == @sizeOf(u32) and
                    @bitSizeOf(@This()) == @bitSizeOf(u32),
            );
        }

        pub const none = UsageFlags{};

        pub fn eql(a: UsageFlags, b: UsageFlags) bool {
            return @as(u11, @truncate(@as(u32, @bitCast(a)))) == @as(u11, @truncate(@as(u32, @bitCast(b))));
        }

        pub fn only(whole: UsageFlags, subset: UsageFlags) bool {
            const subset_bits = @as(u11, @truncate(@as(u32, @bitCast(subset))));
            const whole_bits = @as(u11, @truncate(@as(u32, @bitCast(whole))));
            return (subset_bits & whole_bits) == subset_bits;
        }
    };

    pub const BindingLayout = struct {
        type: BindingType = .undefined,
        has_dynamic_offset: bool = false,
        min_binding_size: u64 = 0,
    };

    pub const Binding = struct {
        buffer: *gpu.Buffer,
        offset: u64,
        size: ?u64,

        pub inline fn resolveSize(self: Binding) u64 {
            if (self.size) |size| {
                return size;
            } else {
                return self.buffer.getSize() - self.offset;
            }
        }
    };

    pub const Descriptor = struct {
        label: ?[]const u8 = null,
        usage: UsageFlags,
        size: u64,
        mapped_at_creation: bool = false,
    };

    pub inline fn getSize(self: *Buffer) u64 {
        return impl.bufferGetSize(self);
    }

    pub inline fn getUsage(self: *Buffer) UsageFlags {
        return impl.bufferGetUsage(self);
    }

    pub inline fn map(self: *Buffer) Error!void {
        return impl.bufferMap(self);
    }

    pub inline fn unmap(self: *Buffer) void {
        impl.bufferUnmap(self);
    }

    pub inline fn getMappedRange(self: *Buffer, offset: usize, size: ?usize) Error![]u8 {
        return impl.bufferGetMappedRange(self, offset, size);
    }

    pub inline fn getMappedRangeConst(self: *Buffer, offset: usize, size: ?usize) Error![]const u8 {
        return impl.bufferGetMappedRangeConst(self, offset, size);
    }

    pub inline fn destroy(self: *Buffer) void {
        impl.bufferDestroy(self);
    }
};
