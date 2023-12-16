const std = @import("std");
const util = @import("util.zig");

pub const Error = error{
    OutOfMemory,
    FailedToMap,
    NoCompatibleMemoryFound,
    InvalidAllocationCreateDesc,
    InvalidAllocatorCreateDesc,
    BarrierLayoutNeedsDevice10,
    Other,
};

pub const MemoryLocation = enum {
    unknown,
    gpu_only,
    cpu_to_gpu,
    gpu_to_cpu,
};

pub const AllocationType = enum {
    free,
    linear,
    non_linear,
};

pub const Report = struct {
    name: []const u8,
    size: u64,
};

pub const Allocation = struct {
    offset: u64,
    chunk: u64,

    pub inline fn add(self: Allocation, offset: u64) Allocation {
        return .{
            .offset = self.offset + offset,
            .chunk = self.chunk,
        };
    }
};

pub const AllocationSizes = struct {
    device_memblock_size: u64 = 256 * 1024 * 1024,
    host_memblock_size: u64 = 64 * 1024 * 1024,

    const four_mb = 4 * 1024 * 1024;
    const two_hundred_fifty_six_mb = 256 * 1024 * 1024;

    pub fn init(
        device_memblock_size: u64,
        host_memblock_size: u64,
    ) AllocationSizes {
        var use_device_memblock_size = std.math.clamp(
            device_memblock_size,
            four_mb,
            two_hundred_fifty_six_mb,
        );
        var use_host_memblock_size = std.math.clamp(
            host_memblock_size,
            four_mb,
            two_hundred_fifty_six_mb,
        );

        if (use_device_memblock_size % four_mb != 0) {
            use_device_memblock_size = four_mb * (@divFloor(use_device_memblock_size, four_mb) + 1);
        }
        if (use_host_memblock_size % four_mb != 0) {
            use_host_memblock_size = four_mb * (@divFloor(use_host_memblock_size, four_mb) + 1);
        }

        return .{
            .device_memblock_size = use_device_memblock_size,
            .host_memblock_size = use_host_memblock_size,
        };
    }
};

pub const Allocator = union(enum) {
    offset_allocator: OffsetAllocator,
    dedicated_block_allocator: DedicatedBlockAllocator,

    pub fn initOffsetAllocator(
        allocator: std.mem.Allocator,
        _size: u32,
        max_allocations: ?u32,
    ) std.mem.Allocator.Error!Allocator {
        return .{
            .offset_allocator = try OffsetAllocator.init(
                allocator,
                _size,
                max_allocations,
            ),
        };
    }

    pub fn initDedicatedBlockAllocator(
        _size: u64,
    ) std.mem.Allocator.Error!Allocator {
        return .{
            .dedicated_block_allocator = DedicatedBlockAllocator.init(
                _size,
            ),
        };
    }

    pub fn deinit(self: *Allocator) void {
        switch (self.*) {
            inline else => |*x| x.deinit(),
        }
    }

    pub fn reset(self: *Allocator) std.mem.Allocator.Error!void {
        switch (self.*) {
            inline else => |x| x.reset(),
        }
    }

    pub fn allocate(
        self: *Allocator,
        name: []const u8,
        _size: u32,
        alignment: ?u32,
    ) Error!Allocation {
        return switch (self.*) {
            inline else => |*x| x.allocate(name, _size, alignment),
        };
    }

    pub fn free(self: *Allocator, allocation: Allocation) Error!void {
        return switch (self.*) {
            inline else => |*x| x.free(allocation),
        };
    }

    pub fn allocationSize(self: *const Allocator, allocation: Allocation) u32 {
        switch (self.*) {
            inline else => |x| x.allocationSize(allocation),
        }
    }

    pub fn reportMemoryLeaks(self: *const Allocator, type_idx: usize, block_idx: usize) void {
        switch (self.*) {
            inline else => |x| x.reportMemoryLeaks(type_idx, block_idx),
        }
    }

    pub fn reportAllocations(self: *const Allocator, allocator: std.mem.Allocator) Error!std.ArrayList(Report) {
        switch (self.*) {
            inline else => |x| x.reportAllocations(allocator),
        }
    }

    pub fn supportsGeneralAllocations(self: *const Allocator) bool {
        switch (self.*) {
            inline else => |x| x.supportsGeneralAllocations(),
        }
    }

    pub fn size(self: *const Allocator) u64 {
        switch (self.*) {
            inline else => |x| x.size(),
        }
    }

    pub fn allocated(self: *const Allocator) u64 {
        switch (self.*) {
            inline else => |x| x.allocated(),
        }
    }

    pub fn availableMemory(self: *const Allocator) u64 {
        return self.size() - self.allocated();
    }

    pub fn isEmpty(self: *const Allocator) bool {
        return self.allocated() == 0;
    }
};

pub const DedicatedBlockAllocator = struct {
    size: u64,
    allocated: u64,
    name: ?[]const u8,

    pub fn init(
        _size: u64,
    ) std.mem.Allocator.Error!DedicatedBlockAllocator {
        return .{
            .size = _size,
            .allocated = 0,
            .name = null,
        };
    }

    pub fn deinit(self: *DedicatedBlockAllocator) void {
        _ = self;
    }

    pub fn allocate(
        self: *DedicatedBlockAllocator,
        name: []const u8,
        _size: u32,
        alignment: ?u32,
    ) Error!Allocation {
        _ = alignment;
        if (self.allocated != 0) {
            return Error.OutOfMemory;
        }

        if (self.size != _size) {
            return Error.OutOfMemory;
        }

        self.allocated = _size;
        self.name = name;

        return .{
            .offset = 0,
            .chunk = 1,
        };
    }

    pub fn free(self: *DedicatedBlockAllocator, allocation: Allocation) Error!void {
        if (self.allocated == 0) {
            return Error.Other;
        }

        if (allocation.chunk != 1) {
            return Error.Other;
        }

        self.allocated = 0;
        self.name = null;
    }

    pub fn allocationSize(self: *const DedicatedBlockAllocator, allocation: Allocation) u32 {
        _ = allocation;
        return @as(u32, @truncate(self.allocated));
    }

    pub fn reportMemoryLeaks(self: *const DedicatedBlockAllocator, type_idx: usize, block_idx: usize) void {
        std.log.warn(
            \\leak detected: {{
            \\    memory type: {}
            \\    memory block: {}
            \\    dedicated block allocator: {{
            \\        size: 0x{:x},
            \\        name: {s},
            \\    }}
            \\}}
        , .{
            type_idx,
            block_idx,
            self.size,
            self.name orelse "<unknown>",
        });
    }

    pub fn reportAllocations(self: *const DedicatedBlockAllocator, allocator: std.mem.Allocator) Error!std.ArrayList(Report) {
        var list = std.ArrayList(Report).initCapacity(allocator, 1) catch
            return Error.OutOfMemory;

        if (self.allocated != 0) {
            list.appendAssumeCapacity(allocator, .{
                .name = self.name orelse "<unknown>",
                .size = self.allocated,
            });
        }

        return list;
    }

    pub fn supportsGeneralAllocations(self: *const DedicatedBlockAllocator) bool {
        _ = self;
        return false;
    }

    pub fn size(self: *const DedicatedBlockAllocator) u64 {
        return self.size;
    }

    pub fn allocated(self: *const DedicatedBlockAllocator) u64 {
        return self.allocated;
    }
};

pub const OffsetAllocator = struct {
    const NodeIndex = u32;

    const Node = struct {
        data_offset: u32 = 0,
        data_size: u32 = 0,
        bin_list_prev: ?NodeIndex = null,
        bin_list_next: ?NodeIndex = null,
        neighbour_prev: ?NodeIndex = null,
        neighbour_next: ?NodeIndex = null,
        used: bool = false,
    };

    const num_top_bins: u32 = 32;
    const bins_per_leaf: u32 = 8;
    const top_bins_index_shift: u32 = 3;
    const lead_bins_index_mask: u32 = 0x7;
    const num_leaf_bins: u32 = num_top_bins * bins_per_leaf;

    allocator: std.mem.Allocator,
    size: u32,
    max_allocations: u32,
    free_storage: u32 = 0,

    used_bins_top: u32 = 0,
    used_bins: [num_top_bins]u8 = undefined,
    bin_indices: [num_leaf_bins]?NodeIndex = undefined,

    nodes: ?[]Node,
    free_nodes: ?[]NodeIndex,
    free_offset: u32 = 0,

    inline fn lzcntNonzero(v: u32) u32 {
        return @clz(v);
    }

    inline fn tzcntNonzero(v: u32) u32 {
        return @ctz(v);
    }

    const SmallFloat = struct {
        const mantissa_bits: u32 = 3;
        const mantissa_value: u32 = 1 << mantissa_bits;
        const mantissa_mask: u32 = mantissa_value - 1;

        pub fn toFloatRoundUp(_size: u32) u32 {
            var exp: u32 = 0;
            var mantissa: u32 = 0;

            if (_size < mantissa_value) {
                mantissa = _size;
            } else {
                const leading_zeros = lzcntNonzero(_size);
                const highestSetBit = 31 - leading_zeros;

                const mantissa_start_bit = highestSetBit - mantissa_bits;
                exp = mantissa_start_bit + 1;
                mantissa = (_size >> @as(u5, @truncate(mantissa_start_bit))) & mantissa_mask;

                const low_bits_mask = (@as(u32, 1) << @as(u5, @truncate(mantissa_start_bit))) - 1;
                if ((_size & low_bits_mask) != 0) {
                    mantissa += 1;
                }
            }

            return (exp << mantissa_bits) + mantissa;
        }

        pub fn toFloatRoundDown(_size: u32) u32 {
            var exp: u32 = 0;
            var mantissa: u32 = 0;

            if (_size < mantissa_value) {
                mantissa = _size;
            } else {
                const leading_zeros = lzcntNonzero(_size);
                const highestSetBit = 31 - leading_zeros;

                const mantissa_start_bit = highestSetBit - mantissa_bits;
                exp = mantissa_start_bit + 1;
                mantissa = (_size >> @as(u5, @truncate(mantissa_start_bit))) & mantissa_mask;
            }

            return (exp << mantissa_bits) | mantissa;
        }
    };

    fn findLowestSetBitAfter(v: u32, start_idx: u32) ?u32 {
        const mask_before_start_index: u32 = (@as(u32, 1) << @as(u5, @truncate(start_idx))) - 1;
        const mask_after_start_index: u32 = ~mask_before_start_index;
        const bits_after: u32 = v & mask_after_start_index;
        if (bits_after == 0) return null;
        return tzcntNonzero(bits_after);
    }

    pub fn init(allocator: std.mem.Allocator, _size: u32, max_allocations: ?u32) std.mem.Allocator.Error!OffsetAllocator {
        var self = OffsetAllocator{
            .allocator = allocator,
            .size = _size,
            .max_allocations = max_allocations orelse 128 * 1024,
            .nodes = null,
            .free_nodes = null,
        };
        try self.reset();
        return self;
    }

    pub fn reset(self: *OffsetAllocator) std.mem.Allocator.Error!void {
        self.free_storage = 0;
        self.used_bins_top = 0;
        self.free_offset = self.max_allocations - 1;

        for (0..num_top_bins) |i| {
            self.used_bins[i] = 0;
        }

        for (0..num_leaf_bins) |i| {
            self.bin_indices[i] = null;
        }

        if (self.nodes) |nodes| {
            self.allocator.free(nodes);
            self.nodes = null;
        }
        if (self.free_nodes) |free_nodes| {
            self.allocator.free(free_nodes);
            self.free_nodes = null;
        }

        self.nodes = try self.allocator.alloc(Node, self.max_allocations);
        self.free_nodes = try self.allocator.alloc(NodeIndex, self.max_allocations);

        for (0..self.max_allocations) |i| {
            self.free_nodes.?[i] = self.max_allocations - @as(u32, @truncate(i)) - 1;
        }

        _ = self.insertNodeIntoBin(self.size, 0);
    }

    pub fn deinit(self: *OffsetAllocator) void {
        if (self.nodes) |nodes| {
            self.allocator.free(nodes);
        }
        if (self.free_nodes) |free_nodes| {
            self.allocator.free(free_nodes);
        }
    }

    pub fn allocate(
        self: *OffsetAllocator,
        name: []const u8,
        _size: u32,
        alignment: ?u32,
    ) Error!Allocation {
        _ = name;
        if (self.free_offset == 0) {
            return Error.OutOfMemory;
        }

        const use_size = util.alignUp(_size, alignment orelse 1);
        const min_bin_index = SmallFloat.toFloatRoundUp(@intCast(use_size));

        const min_top_bin_index: u32 = min_bin_index >> top_bins_index_shift;
        const min_leaf_bin_index: u32 = min_bin_index & lead_bins_index_mask;

        var top_bin_index = min_top_bin_index;
        var leaf_bin_index: ?u32 = null;

        if ((self.used_bins_top & (@as(u32, 1) << @as(u5, @truncate(top_bin_index)))) != 0) {
            leaf_bin_index = findLowestSetBitAfter(self.used_bins[top_bin_index], min_leaf_bin_index);
        }

        if (leaf_bin_index == null) {
            const found_top_bin_index = findLowestSetBitAfter(self.used_bins_top, min_top_bin_index + 1);
            if (found_top_bin_index == null) {
                return Error.OutOfMemory;
            }
            top_bin_index = found_top_bin_index.?;
            leaf_bin_index = tzcntNonzero(self.used_bins[top_bin_index]);
        }

        const bin_index = (top_bin_index << top_bins_index_shift) | leaf_bin_index.?;

        const node_index = self.bin_indices[bin_index].?;
        const node = &self.nodes.?[node_index];
        const node_total_size = node.data_size;
        node.data_size = @intCast(use_size);
        node.used = true;
        self.bin_indices[bin_index] = node.bin_list_next;
        if (node.bin_list_next) |bln| self.nodes.?[bln].bin_list_prev = null;
        self.free_storage -= node_total_size;

        // debug
        // std.debug.print("free storage: {} ({}) (allocate)\n", .{ self.free_storage, node_total_size });

        if (self.bin_indices[bin_index] == null) {
            self.used_bins[top_bin_index] &= @as(u8, @truncate(~(@as(u32, 1) << @as(u5, @truncate(leaf_bin_index.?)))));
            if (self.used_bins[top_bin_index] == 0) {
                self.used_bins_top &= ~(@as(u32, 1) << @as(u5, @truncate(top_bin_index)));
            }
        }

        const remainder_size = node_total_size - use_size;
        if (remainder_size > 0) {
            const new_node_index = self.insertNodeIntoBin(@intCast(remainder_size), @intCast(node.data_offset + use_size));
            if (node.neighbour_next) |nnn| self.nodes.?[nnn].neighbour_prev = new_node_index;
            self.nodes.?[new_node_index].neighbour_prev = node_index;
            self.nodes.?[new_node_index].neighbour_next = node.neighbour_next;
            node.neighbour_next = new_node_index;
        }

        return .{
            .offset = node.data_offset,
            .chunk = node_index,
        };
    }

    pub fn free(self: *OffsetAllocator, allocation: Allocation) Error!void {
        if (self.nodes == null) {
            return Error.Other;
        }

        const node_index = allocation.chunk;
        const node = &self.nodes.?[node_index];
        if (!node.used) {
            return Error.Other;
        }

        var offset = node.data_offset;
        var _size = node.data_size;

        if (node.neighbour_prev != null and self.nodes.?[node.neighbour_prev.?].used == false) {
            const prev_node = &self.nodes.?[node.neighbour_prev.?];
            offset = prev_node.data_offset;
            _size += prev_node.data_size;

            self.removeNodeFromBin(node.neighbour_prev.?);

            std.debug.assert(prev_node.neighbour_next == @as(u32, @truncate(node_index)));
            node.neighbour_prev = prev_node.neighbour_prev;
        }

        if (node.neighbour_next != null and self.nodes.?[node.neighbour_next.?].used == false) {
            const next_node = &self.nodes.?[node.neighbour_next.?];
            _size += next_node.data_size;

            self.removeNodeFromBin(node.neighbour_next.?);

            std.debug.assert(next_node.neighbour_prev == @as(u32, @truncate(node_index)));
            node.neighbour_next = next_node.neighbour_next;
        }

        const neighbour_prev = node.neighbour_prev;
        const neighbour_next = node.neighbour_next;

        // debug
        // std.debug.print("putting node {} into freelist[{}] (free)\n", .{ node_index, self.free_offset + 1 });

        self.free_offset += 1;
        self.free_nodes.?[self.free_offset] = @intCast(node_index);

        const combined_node_index = self.insertNodeIntoBin(_size, offset);
        if (neighbour_next) |nn| {
            self.nodes.?[combined_node_index].neighbour_next = neighbour_next;
            self.nodes.?[nn].neighbour_prev = combined_node_index;
        }
        if (neighbour_prev) |np| {
            self.nodes.?[combined_node_index].neighbour_prev = neighbour_prev;
            self.nodes.?[np].neighbour_next = combined_node_index;
        }
    }

    pub fn insertNodeIntoBin(self: *OffsetAllocator, _size: u32, data_offset: u32) u32 {
        const bin_index = SmallFloat.toFloatRoundDown(_size);

        const top_bin_index: u32 = bin_index >> top_bins_index_shift;
        const leaf_bin_index: u32 = bin_index & lead_bins_index_mask;

        if (self.bin_indices[bin_index] == null) {
            self.used_bins[top_bin_index] |= @as(u8, @truncate(@as(u32, 1) << @as(u5, @truncate(leaf_bin_index))));
            self.used_bins_top |= @as(u32, 1) << @as(u5, @truncate(top_bin_index));
        }

        const top_node_index = self.bin_indices[bin_index];
        const node_index = self.free_nodes.?[self.free_offset];
        self.free_offset -= 1;

        // debug
        // std.debug.print("getting node {} from freelist[{}]\n", .{ node_index, self.free_offset + 1 });

        self.nodes.?[node_index] = .{
            .data_offset = data_offset,
            .data_size = _size,
            .bin_list_next = top_node_index,
        };
        if (top_node_index) |tni| self.nodes.?[tni].bin_list_prev = node_index;
        self.bin_indices[bin_index] = node_index;

        self.free_storage += _size;

        // debug
        // std.debug.print("free storage: {} ({}) (insertNodeIntoBin)\n", .{ self.free_storage, _size });

        return node_index;
    }

    pub fn removeNodeFromBin(self: *OffsetAllocator, node_index: NodeIndex) void {
        const node = &self.nodes.?[node_index];

        if (node.bin_list_prev) |blp| {
            self.nodes.?[blp].bin_list_next = node.bin_list_next;
            if (node.bin_list_next) |bln| self.nodes.?[bln].bin_list_prev = node.bin_list_prev;
        } else {
            const bin_index = SmallFloat.toFloatRoundDown(node.data_size);
            const top_bin_index: u32 = bin_index >> top_bins_index_shift;
            const leaf_bin_index: u32 = bin_index & lead_bins_index_mask;

            self.bin_indices[bin_index] = node.bin_list_next;
            if (node.bin_list_next) |bln| self.nodes.?[bln].bin_list_prev = null;

            if (self.bin_indices[bin_index] == null) {
                self.used_bins[top_bin_index] &= @as(u8, @truncate(~(@as(u32, 1) << @as(u5, @truncate(leaf_bin_index)))));

                if (self.used_bins[top_bin_index] == 0) {
                    self.used_bins_top &= ~(@as(u32, 1) << @as(u5, @truncate(top_bin_index)));
                }
            }
        }

        // debug
        // std.debug.print("putting node {} into freelist[{}] (removeNodeFromBin)\n", .{ node_index, self.free_offset + 1 });
        self.free_offset += 1;
        self.free_nodes.?[self.free_offset] = node_index;

        self.free_storage -= node.data_size;

        // debug
        // std.debug.print("free storage: {} ({}) (removeNodeFromBin)\n", .{ self.free_storage, node.data_size });
    }

    pub fn allocationSize(self: *const OffsetAllocator, allocation: Allocation) u32 {
        return self.nodes.?[allocation.chunk].data_size;
    }

    pub fn reportMemoryLeaks(self: *const OffsetAllocator, type_idx: usize, block_idx: usize) void {
        std.log.warn(
            \\leak detected: {{
            \\    memory type: {}
            \\    memory block: {}
            \\    offset allocator: {{
            \\        size: 0x{:x},
            \\        free storage: 0x{:x},
            \\    }}
            \\}}
        , .{
            type_idx,
            block_idx,
            self.size,
            self.free_storage,
        });
    }

    pub fn reportAllocations(self: *const OffsetAllocator, allocator: std.mem.Allocator) Error!std.ArrayList(Report) {
        var list = std.ArrayList(Report).init(allocator);

        for (0..num_leaf_bins) |i| {
            if (self.bin_indices[i] != null) {
                var node_index = self.bin_indices[i];
                while (node_index != null) : (node_index = self.nodes.?[node_index].bin_list_next) {
                    const node = &self.nodes.?[node_index];
                    try list.append(allocator, .{
                        .name = "",
                        .size = node.data_size,
                    });
                }
            }
        }

        return list;
    }

    pub fn supportsGeneralAllocations(self: *const OffsetAllocator) bool {
        _ = self;

        return true;
    }

    pub fn size(self: *const OffsetAllocator) u64 {
        return self.size;
    }

    pub fn allocated(self: *const OffsetAllocator) u64 {
        return self.size - self.free_storage;
    }
};

test "basic" {
    var allocator = try Allocator.initOffsetAllocator(
        std.testing.allocator,
        1024 * 1024 * 256,
        null,
    );
    defer allocator.deinit();

    const a = try allocator.allocate("test", 1337, null);
    const offset = a.offset;
    try std.testing.expectEqual(@as(u64, 0), offset);
    try allocator.free(a);
}

test "allocate" {
    var allocator = try Allocator.initOffsetAllocator(
        std.testing.allocator,
        1024 * 1024 * 256,
        null,
    );
    defer allocator.deinit();

    {
        const a = try allocator.allocate("a", 0, null);
        try std.testing.expectEqual(@as(u64, 0), a.offset);

        const b = try allocator.allocate("b", 1, null);
        try std.testing.expectEqual(@as(u64, 0), b.offset);

        const c = try allocator.allocate("c", 123, null);
        try std.testing.expectEqual(@as(u64, 1), c.offset);

        const d = try allocator.allocate("d", 1234, null);
        try std.testing.expectEqual(@as(u64, 124), d.offset);

        try allocator.free(a);
        try allocator.free(b);
        try allocator.free(c);
        try allocator.free(d);

        const validate = try allocator.allocate("validate", 1024 * 1024 * 256, null);
        try std.testing.expectEqual(@as(u64, 0), validate.offset);
        try allocator.free(validate);
    }

    {
        const a = try allocator.allocate("a", 1024, null);
        try std.testing.expectEqual(@as(u64, 0), a.offset);

        const b = try allocator.allocate("b", 3456, null);
        try std.testing.expectEqual(@as(u64, 1024), b.offset);

        try allocator.free(a);

        const c = try allocator.allocate("c", 1024, null);
        try std.testing.expectEqual(@as(u64, 0), c.offset);

        try allocator.free(b);
        try allocator.free(c);

        const validate = try allocator.allocate("validate", 1024 * 1024 * 256, null);
        try std.testing.expectEqual(@as(u64, 0), validate.offset);
        try allocator.free(validate);
    }

    {
        const a = try allocator.allocate("a", 1024, null);
        try std.testing.expectEqual(@as(u64, 0), a.offset);

        const b = try allocator.allocate("b", 3456, null);
        try std.testing.expectEqual(@as(u64, 1024), b.offset);

        try allocator.free(a);

        const c = try allocator.allocate("c", 2345, null);
        try std.testing.expectEqual(@as(u64, 1024 + 3456), c.offset);

        const d = try allocator.allocate("d", 456, null);
        try std.testing.expectEqual(@as(u64, 0), d.offset);

        const e = try allocator.allocate("e", 512, null);
        try std.testing.expectEqual(@as(u64, 456), e.offset);

        try allocator.free(b);
        try allocator.free(c);
        try allocator.free(d);
        try allocator.free(e);

        const validate = try allocator.allocate("validate", 1024 * 1024 * 256, null);
        try std.testing.expectEqual(@as(u64, 0), validate.offset);
        try allocator.free(validate);
    }
}
