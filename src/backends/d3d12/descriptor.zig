const std = @import("std");
const gpu = @import("gpu");

const winapi = @import("win32");
const win32 = winapi.windows.win32;
const d3d12 = win32.graphics.direct3d12;

const d3d = @import("d3d");
const gpu_allocator = gpu.allocator;

pub const DescriptorIndex = u64;
pub const DualHandle = struct {
    cpu: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE,
    gpu: d3d12.D3D12_GPU_DESCRIPTOR_HANDLE,
    count: u64,
};

pub const GeneralHeap = struct {
    pub const Error = error{
        GeneralHeapFailedToCreate,
        GeneralHeapOutOfMemory,
    };

    allocator: std.mem.Allocator,
    heap: ?*d3d12.ID3D12DescriptorHeap = null,
    heap_type: d3d12.D3D12_DESCRIPTOR_HEAP_TYPE,
    handle_size: u64,
    total_handles: u64,
    start: DualHandle,
    ranges: gpu_allocator.RangeAllocator,
    mutex: std.Thread.Mutex = .{},

    pub fn init(
        allocator: std.mem.Allocator,
        device: ?*d3d12.ID3D12Device2,
        heap_type: d3d12.D3D12_DESCRIPTOR_HEAP_TYPE,
        total_handles: u64,
    ) !GeneralHeap {
        var heap: ?*d3d12.ID3D12DescriptorHeap = null;
        const heap_hr = device.?.ID3D12Device_CreateDescriptorHeap(
            &.{
                .Type = heap_type,
                .NumDescriptors = @intCast(total_handles),
                .Flags = .SHADER_VISIBLE,
                .NodeMask = 0,
            },
            d3d12.IID_ID3D12DescriptorHeap,
            @ptrCast(&heap),
        );
        if (!d3d.checkHResult(heap_hr)) return Error.GeneralHeapFailedToCreate;
        errdefer d3d.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &heap);

        const cpu_handle = heapStartCpu(heap.?);
        const gpu_handle = heapStartGpu(heap.?);

        return .{
            .allocator = allocator,
            .heap = heap,
            .heap_type = heap_type,
            .handle_size = device.?.ID3D12Device_GetDescriptorHandleIncrementSize(heap_type),
            .total_handles = total_handles,
            .start = .{
                .cpu = cpu_handle,
                .gpu = gpu_handle,
                .count = 0,
            },
            .ranges = try gpu_allocator.RangeAllocator.init(allocator, total_handles),
        };
    }

    pub fn deinit(self: *GeneralHeap) void {
        self.ranges.deinit();
        d3d.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &self.heap);
    }

    pub fn at(self: *const GeneralHeap, index: DescriptorIndex, count: u64) DualHandle {
        std.debug.assert(index + count <= self.total_handles);
        return .{
            .cpu = self.cpuDescriptorAt(index),
            .gpu = self.gpuDescriptorAt(index),
            .count = count,
        };
    }

    pub fn cpuDescriptorAt(self: *const GeneralHeap, index: DescriptorIndex) d3d12.D3D12_CPU_DESCRIPTOR_HANDLE {
        return .{
            .ptr = self.start.cpu.ptr + index * self.handle_size,
        };
    }

    pub fn gpuDescriptorAt(self: *const GeneralHeap, index: DescriptorIndex) d3d12.D3D12_GPU_DESCRIPTOR_HANDLE {
        return .{
            .ptr = self.start.gpu.ptr + index * self.handle_size,
        };
    }

    pub fn alloc(self: *GeneralHeap, size: u32) !DescriptorIndex {
        self.mutex.lock();
        defer self.mutex.unlock();
        return (try self.ranges.allocate(size)).start;
    }

    pub fn free(self: *GeneralHeap, handle: DualHandle) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const start = @divExact(handle.gpu.ptr - self.start.gpu.ptr, self.handle_size);
        self.ranges.free(.{
            .start = start,
            .end = start + handle.count,
        }) catch {};
    }
};

pub const D3D12FixedSizeHeap = struct {
    pub const Error = error{
        FixedSizeHeapFailedToCreate,
    };
    const size = 64;

    heap: ?*d3d12.ID3D12DescriptorHeap = null,
    availability: u64 = ~@as(u64, 0),
    handle_size: u64 = 0,
    start: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE,

    pub fn init(
        device: ?*d3d12.ID3D12Device2,
        heap_type: d3d12.D3D12_DESCRIPTOR_HEAP_TYPE,
        handle_size: u64,
    ) !D3D12FixedSizeHeap {
        var heap: ?*d3d12.ID3D12DescriptorHeap = null;
        const heap_hr = device.?.ID3D12Device_CreateDescriptorHeap(
            &.{
                .Type = heap_type,
                .NumDescriptors = D3D12FixedSizeHeap.size,
                .Flags = .NONE,
                .NodeMask = 0,
            },
            d3d12.IID_ID3D12DescriptorHeap,
            @ptrCast(&heap),
        );
        if (!d3d.checkHResult(heap_hr)) return Error.FixedSizeHeapFailedToCreate;

        return .{
            .heap = heap,
            .handle_size = handle_size,
            .start = heapStartCpu(heap.?),
        };
    }

    pub fn deinit(self: *D3D12FixedSizeHeap) void {
        d3d.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &self.heap);
    }

    pub fn alloc(self: *D3D12FixedSizeHeap) !d3d12.D3D12_CPU_DESCRIPTOR_HANDLE {
        const slot: u6 = @intCast(@ctz(self.availability));
        std.debug.assert(slot < D3D12FixedSizeHeap.size);
        self.availability ^= @as(u64, 1) << slot;

        return .{
            .ptr = self.start.ptr + slot * self.handle_size,
        };
    }

    pub fn free(self: *D3D12FixedSizeHeap, handle: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE) void {
        const slot: u6 = @intCast(@divExact(handle.ptr - self.start.ptr, self.handle_size));
        std.debug.assert(slot < D3D12FixedSizeHeap.size);
        std.debug.assert(self.availability & (@as(u64, 1) << slot) == 0);
        self.availability ^= @as(u64, 1) << slot;
    }

    pub fn isFull(self: *const D3D12FixedSizeHeap) bool {
        return self.availability == 0;
    }
};

pub const Handle = struct {
    cpu_descriptor: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE,
    heap_index: usize,
};

pub const CpuPool = struct {
    device: ?*d3d12.ID3D12Device2,
    heap_type: d3d12.D3D12_DESCRIPTOR_HEAP_TYPE,
    heaps: std.ArrayList(D3D12FixedSizeHeap),
    available_heap_indices: std.bit_set.IntegerBitSet(32),
    handle_size: u64,

    pub fn init(
        allocator: std.mem.Allocator,
        device: ?*d3d12.ID3D12Device2,
        heap_type: d3d12.D3D12_DESCRIPTOR_HEAP_TYPE,
    ) CpuPool {
        return .{
            .device = device,
            .heap_type = heap_type,
            .heaps = std.ArrayList(D3D12FixedSizeHeap).init(allocator),
            .available_heap_indices = std.bit_set.IntegerBitSet(32).initEmpty(),
            .handle_size = device.?.ID3D12Device_GetDescriptorHandleIncrementSize(heap_type),
        };
    }

    pub fn deinit(self: *CpuPool) void {
        self.heaps.deinit();
    }

    pub fn alloc(self: *CpuPool) !Handle {
        var it = self.available_heap_indices.iterator(.{});
        const index = it.next() orelse blk: {
            const id = self.heaps.items.len;
            try self.heaps.append(try D3D12FixedSizeHeap.init(self.device, self.heap_type, self.handle_size));
            self.available_heap_indices.set(id);
            break :blk id;
        };
        const heap = &self.heaps.items[index];
        const handle = Handle{
            .cpu_descriptor = try heap.alloc(),
            .heap_index = index,
        };
        if (heap.isFull()) self.available_heap_indices.unset(index);
        return handle;
    }

    pub fn free(self: *CpuPool, handle: Handle) void {
        self.heaps.items[handle.heap_index].free(handle.cpu_descriptor);
        self.available_heap_indices.set(handle.heap_index);
    }
};

pub const CpuHeapInner = struct {
    heap: ?*d3d12.ID3D12DescriptorHeap = null,
    stage: std.ArrayList(d3d12.D3D12_CPU_DESCRIPTOR_HANDLE),
};

pub const CpuHeap = struct {
    pub const Error = error{
        CpuHeapFailedToCreate,
    };

    inner: CpuHeapInner,
    mutex: std.Thread.Mutex = .{},
    start: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE,
    handle_size: u64,
    total: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        device: ?*d3d12.ID3D12Device2,
        heap_type: d3d12.D3D12_DESCRIPTOR_HEAP_TYPE,
        total: u32,
    ) !CpuHeap {
        const handle_size = device.?.ID3D12Device_GetDescriptorHandleIncrementSize(heap_type);
        var heap: ?*d3d12.ID3D12DescriptorHeap = null;
        const heap_hr = device.?.ID3D12Device_CreateDescriptorHeap(
            &.{
                .Type = heap_type,
                .NumDescriptors = total,
                .Flags = .NONE,
                .NodeMask = 0,
            },
            d3d12.IID_ID3D12DescriptorHeap,
            @ptrCast(&heap),
        );
        if (!d3d.checkHResult(heap_hr)) return Error.CpuHeapFailedToCreate;

        return .{
            .inner = .{
                .heap = heap,
                .stage = std.ArrayList(d3d12.D3D12_CPU_DESCRIPTOR_HANDLE).init(allocator),
            },
            .start = heapStartCpu(heap.?),
            .handle_size = handle_size,
            .total = total,
        };
    }

    pub fn deinit(self: *CpuHeap) void {
        d3d.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &self.inner.heap);
        self.inner.stage.deinit();
    }

    pub fn at(self: *const CpuHeap, index: u3) d3d12.D3D12_CPU_DESCRIPTOR_HANDLE {
        return .{
            .ptr = self.start.ptr + (self.handle_size * index),
        };
    }
};

pub fn upload(
    device: ?*d3d12.ID3D12Device2,
    src: *const CpuHeapInner,
    dst: *const GeneralHeap,
    copy_counts: []const u32,
) !DualHandle {
    const count: u32 = @intCast(src.stage.items.len);
    const index = dst.alloc(count);
    device.?.ID3D12Device_CopyDescriptors(
        device.?,
        1,
        &dst.cpuDescriptorAt(index),
        @ptrCast(&count),
        count,
        src.stage.items.ptr,
        copy_counts.ptr,
        dst.heap_type,
    );

    return dst.at(index, @intCast(count));
}

fn heapStartCpu(heap: *d3d12.ID3D12DescriptorHeap) d3d12.D3D12_CPU_DESCRIPTOR_HANDLE {
    var cpu_handle: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE = undefined;

    const getCpuDescriptorHandleForHeapStart: (*const fn (
        self: *const d3d12.ID3D12DescriptorHeap,
        out_handle: *d3d12.D3D12_CPU_DESCRIPTOR_HANDLE,
    ) callconv(.Win64) d3d12.D3D12_CPU_DESCRIPTOR_HANDLE) = @ptrCast(
        heap.vtable.GetCPUDescriptorHandleForHeapStart,
    );

    _ = getCpuDescriptorHandleForHeapStart(heap, &cpu_handle);
    return cpu_handle;
}

fn heapStartGpu(heap: *d3d12.ID3D12DescriptorHeap) d3d12.D3D12_GPU_DESCRIPTOR_HANDLE {
    var gpu_handle: d3d12.D3D12_GPU_DESCRIPTOR_HANDLE = undefined;

    const getGpuDescriptorHandleForHeapStart: (*const fn (
        self: *const d3d12.ID3D12DescriptorHeap,
        out_handle: *d3d12.D3D12_GPU_DESCRIPTOR_HANDLE,
    ) callconv(.Win64) d3d12.D3D12_GPU_DESCRIPTOR_HANDLE) = @ptrCast(
        heap.vtable.GetGPUDescriptorHandleForHeapStart,
    );

    _ = getGpuDescriptorHandleForHeapStart(heap, &gpu_handle);
    return gpu_handle;
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
