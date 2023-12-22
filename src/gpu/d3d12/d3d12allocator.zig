const std = @import("std");
const allocator = @import("../allocator.zig");

const winapi = @import("win32");
const win32 = winapi.windows.win32;
const d3d = win32.graphics.direct3d;
const d3d12 = win32.graphics.direct3d12;

const d3dcommon = @import("../d3d/common.zig");

const common = @import("../../core/common.zig");

pub const ResourceCategory = enum {
    buffer,
    rtv_dsv_texture,
    other_texture,

    const rtv_dsv_flags = d3d12.D3D12_RESOURCE_FLAGS.initFlags(.{
        .ALLOW_RENDER_TARGET = 1,
        .ALLOW_DEPTH_STENCIL = 1,
    });
    pub inline fn fromD3d12ResourceDesc(desc: *const d3d12.D3D12_RESOURCE_DESC) ResourceCategory {
        if (desc.Dimension == .BUFFER) return .buffer;
        if ((@intFromEnum(desc.Flags) &
            @intFromEnum(rtv_dsv_flags)) != 0) return .rtv_dsv_texture;
        return .other_texture;
    }
};

pub const ResourceStateOrBarrierLayout = union(enum) {
    resource_state: d3d12.D3D12_RESOURCE_STATES,
    barrier_layout: d3d12.D3D12_RESOURCE_BARRIER_TYPE,
};

pub const ResourceCreateDescriptor = struct {
    name: []const u8,
    location: allocator.MemoryLocation,
    resource_category: ResourceCategory,
    resource_desc: *const d3d12.D3D12_RESOURCE_DESC,
    clear_value: ?*const d3d12.D3D12_CLEAR_VALUE,
    initial_state_or_layout: ResourceStateOrBarrierLayout,
    resource_type: ResourceType,
};

pub const HeapCategory = enum {
    all,
    buffer,
    rtv_dsv_texture,
    other_texture,

    pub inline fn fromResourceCategory(category: ResourceCategory) !HeapCategory {
        switch (category) {
            .buffer => return .buffer,
            .rtv_dsv_texture => return .rtv_dsv_texture,
            .other_texture => return .other_texture,
        }
    }
};

pub const AllocationCreateDescriptor = struct {
    name: []const u8,
    location: allocator.MemoryLocation,
    size: u64,
    alignment: u64,
    resource_category: ResourceCategory,

    pub inline fn fromD3D12ResourceDesc(
        device: *const d3d12.ID3D12Device,
        desc: *const d3d12.D3D12_RESOURCE_DESC,
        name: []const u8,
        location: allocator.MemoryLocation,
    ) !AllocationCreateDescriptor {
        const allocation_info = device.ID3D12Device_GetResourceAllocationInfo(
            0,
            1,
            @ptrCast(desc),
        );
        const resource_category = ResourceCategory.fromD3d12ResourceDesc(desc);

        return AllocationCreateDescriptor{
            .name = name,
            .location = location,
            .size = allocation_info.SizeInBytes,
            .alignment = allocation_info.Alignment,
            .resource_category = resource_category,
        };
    }
};

pub const ID3D12DeviceVersioned = union(enum) {
    device: *d3d12.ID3D12Device,
    device10: *d3d12.ID3D12Device10,

    pub inline fn toDevice(self: ID3D12DeviceVersioned) *d3d12.ID3D12Device {
        return switch (self) {
            .device => self.device,
            .device10 => |d10| blk: {
                var p_device: ?*d3d12.ID3D12Device = null;
                _ = d10.IUnknown_QueryInterface(d3d12.IID_ID3D12Device, @ptrCast(&p_device));
                break :blk p_device.?;
            },
        };
    }
};

pub const AllocatorCreateDesc = struct {
    device: ID3D12DeviceVersioned,
    // debug_settings: allocator.DebugSettings,
    allocation_sizes: allocator.AllocationSizes,
};

pub const ResourceType = union(enum) {
    committed: struct {
        properties: *const d3d12.D3D12_HEAP_PROPERTIES,
        flags: d3d12.D3D12_HEAP_FLAGS,
    },
    placed: void,
};

pub const Resource = struct {
    name: []const u8,
    allocation: ?allocator.Allocation,
    resource: ?*d3d12.ID3D12Resource,
    memory_location: allocator.MemoryLocation,
    memory_type_index: ?usize,
    size: u64,

    pub fn deinit(self: *Resource) void {
        if (self.resource) |_| {
            std.log.warn("Releasing resource that was not freed: {}", .{self.name});
            d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, &self.resource);
        }
    }
};

pub const CommittedAllocationStatistics = struct {
    num_allocation: usize,
    total_size: u54,
};

pub const Allocation = struct {
    chunk_id: ?u64,
    offset: u64,
    size: u64,
    memory_block_index: usize,
    memory_type_index: usize,
    heap: *d3d12.ID3D12Heap,
    name: ?[]const u8,
};

pub const MemoryBlock = struct {
    heap: *d3d12.ID3D12Heap,
    size: u64,
    allocator: allocator.Allocator,

    pub fn init(
        al: std.mem.Allocator,
        device: *d3d12.ID3D12Device,
        size: u64,
        heap_properties: *const d3d12.D3D12_HEAP_PROPERTIES,
        heap_category: HeapCategory,
        dedicated: bool,
    ) allocator.Error!MemoryBlock {
        const heap = blk: {
            var desc = d3d12.D3D12_HEAP_DESC{
                .SizeInBytes = size,
                .Properties = *heap_properties,
                .Alignment = @intCast(d3d12.D3D12_DEFAULT_MSAA_RESOURCE_PLACEMENT_ALIGNMENT),
            };
            desc.Flags = switch (heap_category) {
                .all => .NONE,
                .buffer => .ALLOW_ONLY_BUFFERS,
                .rtv_dsv_texture => .ALLOW_ONLY_RT_DS_TEXTURES,
                .other_texture => .ALLOW_ONLY_NON_RT_DS_TEXTURES,
            };

            var heap: ?*d3d12.ID3D12Heap = null;
            const hr = device.ID3D12Device_CreateHeap(
                &desc,
                d3d12.IID_ID3D12Heap,
                @ptrCast(&heap),
            );
            if (hr == win32.foundation.E_OUTOFMEMORY) return allocator.Error.OutOfMemory;
            if (!d3dcommon.checkHResult(hr)) return allocator.Error.Other;

            break :blk heap.?;
        };

        const sub_allocator = try (if (dedicated)
            allocator.Allocator.initDedicatedBlockAllocator(size)
        else
            allocator.Allocator.initOffsetAllocator(al, size, null));

        return MemoryBlock{
            .heap = heap,
            .size = size,
            .allocator = sub_allocator,
        };
    }
};

pub const MemoryType = struct {
    memory_blocks: std.ArrayList(?MemoryBlock),
    committed_allocated: CommittedAllocationStatistics,
    memory_location: allocator.MemoryLocation,
    heap_category: HeapCategory,
    heap_properties: d3d12.D3D12_HEAP_PROPERTIES,
    memory_type_index: usize,
    active_general_blocks: usize,

    pub fn allocate(
        self: *MemoryType,
        al: std.mem.Allocator,
        device: ID3D12DeviceVersioned,
        desc: *const AllocationCreateDescriptor,
        allocation_sizes: *const allocator.AllocationSizes,
    ) allocator.Error!Allocation {
        const allocation_type = allocator.AllocationType.linear;
        _ = allocation_type;
        const memblock_size: u64 = if (self.heap_properties.Type == .DEFAULT)
            allocation_sizes.device_memblock_size
        else
            allocation_sizes.host_memblock_size;

        const size = desc.size;
        const alignment = desc.alignment;
        _ = alignment;

        if (size > memblock_size) {
            const mem_block = try MemoryBlock.init(
                al,
                device.toDevice(),
                size,
                &self.heap_properties,
                self.heap_category,
                true,
            );
            _ = mem_block;
        }
    }
};
