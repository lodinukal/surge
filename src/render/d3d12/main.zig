const std = @import("std");
const gpu = @import("../gpu.zig");

const winapi = @import("win32");
const win32 = winapi.windows.win32;
const d3d = win32.graphics.direct3d;
const d3d12 = win32.graphics.direct3d12;
const dxgi = win32.graphics.dxgi;
const hlsl = win32.graphics.hlsl;

const general_heap_size = 1024;
const general_block_size = 16;
const sampler_heap_size = 1024;
const sampler_block_size = 16;
const rtv_heap_size = 1024;
const rtv_block_size = 16;
const dsv_heap_size = 1024;
const dsv_block_size = 1;
const upload_page_size = 64 * 1024 * 1024; // TODO - split writes and/or support large uploads
const max_back_buffer_count = 3;

const TRUE = win32.foundation.TRUE;
const FALSE = win32.foundation.FALSE;

const d3dcommon = @import("../d3d/common.zig");

const common = @import("../../core/common.zig");

// Loading
pub const procs: gpu.procs.Procs = .{
    // BindGroup
    // BindGroupLayout
    .bindGroupLayoutDestroy = bindGroupLayoutDestroy,
    // Buffer
    .bufferGetSize = bufferGetSize,
    .bufferGetUsage = bufferGetUsage,
    .bufferMap = bufferMap,
    .bufferUnmap = bufferUnmap,
    .bufferGetMappedRange = bufferGetMappedRange,
    .bufferGetMappedRangeConst = bufferGetMappedRangeConst,
    .bufferDestroy = bufferDestroy,
    // CommandBuffer
    .commandBufferDestroy = commandBufferDestroy,
    // CommandEncoder
    .commandEncoderFinish = commandEncoderFinish,
    .commandEncoderDestroy = commandEncoderDestroy,
    // ComputePassEncoder
    // ComputePipeline
    // Device
    .deviceCreateBuffer = deviceCreateBuffer,
    .deviceCreateSampler = deviceCreateSampler,
    .deviceCreateSwapChain = deviceCreateSwapChain,
    .deviceCreateTexture = deviceCreateTexture,
    .deviceGetQueue = deviceGetQueue,
    .deviceDestroy = deviceDestroy,
    // Instance
    .createInstance = createInstance,
    .instanceCreateSurface = instanceCreateSurface,
    .instanceRequestPhysicalDevice = instanceRequestPhysicalDevice,
    .instanceDestroy = instanceDestroy,
    // PhysicalDevice
    .physicalDeviceCreateDevice = physicalDeviceCreateDevice,
    .physicalDeviceGetProperties = physicalDeviceGetProperties,
    .physicalDeviceDestroy = physicalDeviceDestroy,
    // PipelineLayout
    // QuerySet
    // Queue
    .queueSubmit = queueSubmit,
    // RenderBundle
    // RenderBundleEncoder
    // RenderPassEncoder
    // RenderPipeline
    // Sampler
    .samplerDestroy = samplerDestroy,
    // ShaderModule
    // Surface
    .surfaceDestroy = surfaceDestroy,
    // SwapChain
    .swapChainGetCurrentTexture = swapChainGetCurrentTexture,
    .swapChainGetCurrentTextureView = swapChainGetCurrentTextureView,
    .swapChainPresent = swapChainPresent,
    .swapChainResize = swapChainResize,
    .swapChainDestroy = swapChainDestroy,
};

export fn getProcs() *const gpu.procs.Procs {
    return &procs;
}

// BindGroup
// BindGroupLayout
pub fn bindGroupLayoutDestroy(bind_group_layout: *gpu.BindGroupLayout) void {
    std.debug.print("destroying bind group layout...\n", .{});
    D3D12BindGroupLayout.deinit(@alignCast(@ptrCast(bind_group_layout)));
}

pub const D3D12BindGroupLayout = struct {
    pub fn deinit(self: *D3D12BindGroupLayout) void {
        allocator.destroy(self);
    }
};

// Buffer
pub fn bufferGetSize(buffer: *gpu.Buffer) usize {
    return D3D12Buffer.getSize(@ptrCast(@alignCast(buffer)));
}

pub fn bufferGetUsage(buffer: *gpu.Buffer) gpu.Buffer.UsageFlags {
    return D3D12Buffer.getUsage(@ptrCast(@alignCast(buffer)));
}

pub fn bufferMap(buffer: *gpu.Buffer) gpu.Buffer.Error!void {
    std.debug.print("mapping buffer...\n", .{});
    return D3D12Buffer.map(@ptrCast(@alignCast(buffer))) catch return gpu.Buffer.Error.BufferMapFailed;
}

pub fn bufferUnmap(buffer: *gpu.Buffer) void {
    std.debug.print("unmapping buffer...\n", .{});
    D3D12Buffer.unmap(@ptrCast(@alignCast(buffer)));
}

pub fn bufferGetMappedRange(buffer: *gpu.Buffer, offset: usize, size: ?usize) gpu.Buffer.Error![]u8 {
    std.debug.print("getting mapped range...\n", .{});
    return D3D12Buffer.getMappedRange(@ptrCast(@alignCast(buffer)), offset, size, true);
}

pub fn bufferGetMappedRangeConst(buffer: *gpu.Buffer, offset: usize, size: ?usize) gpu.Buffer.Error![]const u8 {
    std.debug.print("getting mapped range const...\n", .{});
    return D3D12Buffer.getMappedRange(@ptrCast(@alignCast(buffer)), offset, size, false);
}

pub fn bufferDestroy(buffer: *gpu.Buffer) void {
    std.debug.print("destroying buffer...\n", .{});
    D3D12Buffer.deinit(@alignCast(@ptrCast(buffer)));
}

pub const D3D12Buffer = struct {
    device: *D3D12Device,

    size: u64,
    usage: gpu.Buffer.UsageFlags,

    staging_buffer: ?*D3D12Buffer = null, // used for initial mapping
    buffer: D3D12Resource,

    mapped: ?[]u8 = null,
    mapped_at_creation: bool = false,

    pub fn init(device: *D3D12Device, desc: *const gpu.Buffer.Descriptor) gpu.Buffer.Error!*D3D12Buffer {
        var resource = device.createD3dBuffer(
            desc.usage,
            desc.size,
        ) catch return gpu.Buffer.Error.BufferFailedToCreate;
        errdefer resource.deinit();

        var stage: ?*D3D12Buffer = null;
        var mapped: ?*anyopaque = null;

        if (desc.mapped_at_creation) {
            var map_resource: ?*d3d12.ID3D12Resource = null;
            if (!desc.usage.map_write) {
                stage = try D3D12Buffer.init(device, &.{
                    .usage = .{
                        .copy_src = true,
                        .map_write = true,
                    },
                    .size = desc.size,
                });
                map_resource = stage.?.buffer.resource;
            } else {
                map_resource = resource.resource;
            }

            const map_hr = map_resource.?.ID3D12Resource_Map(
                0,
                null,
                &mapped,
            );
            if (!d3dcommon.checkHResult(map_hr)) return gpu.Buffer.Error.BufferMapAtCreationFailed;
        }

        const self = allocator.create(D3D12Buffer) catch return gpu.Buffer.Error.BufferFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .device = device,
            .size = desc.size,
            .usage = desc.usage,
            .staging_buffer = stage,
            .buffer = resource,
            .mapped = if (mapped) |m| @ptrCast(
                @as([*]u8, @ptrCast(m))[0..desc.size],
            ) else null,
        };

        return self;
    }

    pub fn deinit(self: *D3D12Buffer) void {
        if (self.staging_buffer) |sb| sb.deinit();
        var proxy: ?*d3d12.ID3D12Resource = self.buffer.resource;
        d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, &proxy);
        allocator.destroy(self);
    }

    pub fn getSize(self: *D3D12Buffer) u64 {
        return self.size;
    }

    pub fn getUsage(self: *D3D12Buffer) gpu.Buffer.UsageFlags {
        return self.usage;
    }

    pub fn map(self: *D3D12Buffer) gpu.Buffer.Error!void {
        if (self.mapped != null) return gpu.Buffer.Error.BufferAlreadyMapped;
        if (!self.usage.map_write) return gpu.Buffer.Error.BufferNotMappable;

        var mapped: ?*anyopaque = null;
        const hr_map = self.buffer.resource.?.ID3D12Resource_Map(0, null, &mapped);
        if (!d3dcommon.checkHResult(hr_map)) return gpu.Buffer.Error.BufferMapFailed;

        self.mapped = if (mapped) |data|
            @ptrCast(@as([*]u8, @ptrCast(data))[0..self.size])
        else
            null;
    }

    pub fn unmap(self: *D3D12Buffer) void {
        if (self.mapped == null) return;

        var map_resource: ?*d3d12.ID3D12Resource = null;
        if (self.staging_buffer) |sb| {
            map_resource = sb.buffer.resource;
            const ce = self.device.queue.getCommandEncoder() catch unreachable;
            ce.copyBufferToBuffer(sb, 0, self, 0, self.size) catch unreachable;
            // sb.deinit();
            // self.staging_buffer = null;
        } else {
            map_resource = self.buffer.resource;
        }

        map_resource.?.ID3D12Resource_Unmap(0, null);

        self.mapped = null;
    }

    pub fn getMappedRange(self: *D3D12Buffer, offset: usize, size: ?usize, writing: bool) gpu.Buffer.Error![]u8 {
        const use_size = size orelse (self.size - offset);
        if (self.staging_buffer == null) {
            if (!(self.usage.map_read or self.usage.map_write)) return gpu.Buffer.Error.BufferInvalidMapAccess;
            if (!self.usage.map_write and writing) return gpu.Buffer.Error.BufferInvalidMapAccess;
        }

        if (self.mapped) |m| return m[offset .. offset + use_size] else return gpu.Buffer.Error.BufferNotMapped;
    }
};

// CommandBuffer
pub fn commandBufferDestroy(command_buffer: *gpu.CommandBuffer) void {
    std.debug.print("destroying command buffer...\n", .{});
    D3D12CommandBuffer.deinit(@alignCast(@ptrCast(command_buffer)));
}

pub const D3D12CommandBuffer = struct {
    pub const StreamingResult = struct {
        d3d_resource: ?*d3d12.ID3D12Resource,
        map: [*]u8,
        offset: u32,
    };

    device: *D3D12Device,
    command_allocator: ?*d3d12.ID3D12CommandAllocator = null,
    command_list: ?*d3d12.ID3D12GraphicsCommandList = null,
    rtv_allocation: D3D12DescriptorHeap.Allocation = 0,
    rtv_next_index: u32 = rtv_block_size,
    upload_buffer: ?*d3d12.ID3D12Resource = null,
    upload_map: ?[*]u8 = null,
    upload_next_offset: u32 = upload_page_size,

    pub fn init(
        device: *D3D12Device,
    ) gpu.CommandBuffer.Error!*D3D12CommandBuffer {
        const command_allocator = device.command_pool.createCommandAllocator() catch
            return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        errdefer device.command_pool.destroyCommandAllocator(command_allocator);

        const command_list = device.command_pool.createCommandList(command_allocator) catch
            return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        errdefer device.command_pool.destroyCommandList(command_list);

        var heaps = [2]*d3d12.ID3D12DescriptorHeap{
            device.general_heap.heap.?,
            device.sampler_heap.heap.?,
        };
        command_list.ID3D12GraphicsCommandList_SetDescriptorHeaps(2, @ptrCast(&heaps));

        const self = allocator.create(
            D3D12CommandBuffer,
        ) catch return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        self.* = .{
            .device = device,
            .command_allocator = command_allocator,
            .command_list = command_list,
        };
        return self;
    }

    pub fn deinit(self: *D3D12CommandBuffer) void {
        allocator.destroy(self);
    }

    pub fn upload(self: *D3D12CommandBuffer, size: u64) !StreamingResult {
        if (self.upload_next_offset + size > upload_page_size) {
            std.debug.assert(size <= upload_page_size);
            const resource = try self.device.streaming_pool.acquire();

            self.upload_buffer = resource;

            var map: ?*anyopaque = null;
            const hr_map = resource.?.ID3D12Resource_Map(0, null, &map);
            if (!d3dcommon.checkHResult(hr_map)) return gpu.CommandBuffer.Error.CommandBufferMapForUploadFailed;

            self.upload_map = @ptrCast(map);
            self.upload_next_offset = 0;
        }

        const offset = self.upload_next_offset;
        self.upload_next_offset = @intCast(
            gpu.util.alignUp(
                offset + size,
                gpu.limits.min_uniform_buffer_offset_alignment,
            ),
        );

        return .{
            .resource = self.upload_buffer.?,
            .map = self.upload_map.?[offset .. offset + size],
            .offset = offset,
        };
    }

    pub fn allocateRtvDescriptors(self: *D3D12CommandBuffer, count: usize) !d3d12.D3D12_CPU_DESCRIPTOR_HANDLE {
        if (count == 0) return .{ .ptr = 0 };

        var rtv_heap = &self.device.rtv_heap;

        if (self.rtv_next_index + count > rtv_block_size) {
            self.rtv_allocation = try rtv_heap.alloc();
            self.rtv_next_index = 0;
        }

        const index = self.rtv_next_index;
        self.rtv_next_index = @intCast(index + count);
        return rtv_heap.cpuDescriptor(self.rtv_allocation + index);
    }

    pub fn allocateDsvDescriptor(self: *D3D12CommandBuffer) !d3d12.D3D12_CPU_DESCRIPTOR_HANDLE {
        var dsv_heap = &self.device.dsv_heap;

        const allocation = try dsv_heap.alloc();

        return dsv_heap.cpuDescriptor(allocation);
    }
};

// CommandEncoder
pub fn commandEncoderFinish(
    command_encoder: *gpu.CommandEncoder,
    desc: *const gpu.CommandBuffer.Descriptor,
) gpu.CommandBuffer.Error!*gpu.CommandBuffer {
    std.debug.print("finishing command encoder...\n", .{});
    return @ptrCast(try D3D12CommandEncoder.finish(@ptrCast(@alignCast(command_encoder)), desc));
}

pub fn commandEncoderDestroy(command_encoder: *gpu.CommandEncoder) void {
    std.debug.print("destroying command encoder...\n", .{});
    D3D12CommandEncoder.deinit(@alignCast(@ptrCast(command_encoder)));
}

pub const D3D12CommandEncoder = struct {
    device: *D3D12Device,
    command_buffer: *D3D12CommandBuffer,
    barrier_enforcer: D3D12BarrierEnforcer = .{},

    pub fn init(device: *D3D12Device, desc: *const gpu.CommandEncoder.Descriptor) gpu.CommandEncoder.Error!*D3D12CommandEncoder {
        _ = desc;

        const command_buffer = D3D12CommandBuffer.init(device) catch
            return gpu.CommandEncoder.Error.CommandEncoderFailedToCreate;

        const self = allocator.create(
            D3D12CommandEncoder,
        ) catch return gpu.CommandEncoder.Error.CommandEncoderFailedToCreate;
        self.* = .{
            .device = device,
            .command_buffer = command_buffer,
        };

        self.barrier_enforcer.init(device);

        return self;
    }

    pub fn deinit(self: *D3D12CommandEncoder) void {
        self.barrier_enforcer.deinit();
        self.command_buffer.deinit();
        allocator.destroy(self);
    }

    pub fn copyBufferToBuffer(
        self: *D3D12CommandEncoder,
        src: *D3D12Buffer,
        src_offset: u64,
        dst: *D3D12Buffer,
        dst_offset: u64,
        size: u64,
    ) !void {
        const command_list = self.command_buffer.command_list.?;

        try self.barrier_enforcer.transition(&src.buffer, src.buffer.read_state);
        try self.barrier_enforcer.transition(&dst.buffer, .COPY_DEST);
        self.barrier_enforcer.flush(command_list);

        command_list.ID3D12GraphicsCommandList_CopyBufferRegion(
            dst.buffer.resource,
            dst_offset,
            src.buffer.resource,
            src_offset,
            size,
        );
    }

    pub fn copyBufferToTexture(
        self: *D3D12CommandEncoder,
        src: *const gpu.ImageCopyBuffer,
        dst: *const gpu.ImageCopyTexture,
        copy_size_raw: *const gpu.Extent3D,
    ) !void {
        const command_list = self.command_buffer.command_list.?;
        const source_buffer: *D3D12Buffer = @ptrCast(@alignCast(src.buffer));
        const destination_texture: *D3D12Texture = @ptrCast(@alignCast(dst.texture));

        try self.barrier_enforcer.transition(&source_buffer.buffer, source_buffer.buffer.read_state);
        try self.barrier_enforcer.transition(&destination_texture.texture, .COPY_DEST);
        self.barrier_enforcer.flush(command_list);

        const copy_size = gpu.util.calcExtent(
            destination_texture.dimension,
            copy_size_raw.*,
        );
        const destination_origin = gpu.util.calcOrigin(
            destination_texture.dimension,
            dst.origin,
        );
        const destination_subresource_index = destination_texture.calcSubresource(
            dst.mip_level,
            destination_origin.array_slice,
        );

        std.debug.assert(copy_size.array_count == 1);

        command_list.ID3D12GraphicsCommandList_CopyTextureRegion(
            &.{
                .pResource = destination_texture.resource.d3d_resource,
                .Type = .SUBRESOURCE_INDEX,
                .Anonymous = .{
                    .SubresourceIndex = destination_subresource_index,
                },
            },
            destination_origin.x,
            destination_origin.y,
            destination_origin.z,
            &.{
                .pResource = source_buffer.resource.d3d_resource,
                .Type = .PLACED_FOOTPRINT,
                .Anonymous = .{
                    .PlacedFootprint = .{
                        .Offset = src.layout.offset,
                        .Footprint = .{
                            .Format = d3dcommon.dxgiFormatForTexture(destination_texture.format),
                            .Width = copy_size.width,
                            .Height = copy_size.height,
                            .Depth = copy_size.depth,
                            .RowPitch = src.layout.bytes_per_row,
                        },
                    },
                },
            },
            null,
        );
    }

    pub fn copyTextureToTexture(
        self: *D3D12CommandEncoder,
        src: *const gpu.ImageCopyTexture,
        dst: *const gpu.ImageCopyTexture,
        copy_size_raw: *const gpu.Extent3D,
    ) !void {
        const command_list = self.command_buffer.command_list;
        const source_texture: *D3D12Texture = @ptrCast(@alignCast(src.texture));
        const destination_texture: *D3D12Texture = @ptrCast(@alignCast(dst.texture));

        try self.barrier_enforcer.transition(&source_texture.resource, source_texture.resource.read_state);
        try self.barrier_enforcer.transition(&destination_texture.resource, .COPY_DEST);
        self.barrier_enforcer.flush(command_list);

        const copy_size = gpu.util.calcExtent(
            destination_texture.dimension,
            copy_size_raw.*,
        );
        const source_origin = gpu.util.calcOrigin(
            source_texture.dimension,
            src.origin,
        );
        const destination_origin = gpu.util.calcOrigin(
            destination_texture.dimension,
            dst.origin,
        );

        const source_subresource_index = source_texture.calcSubresource(
            src.mip_level,
            source_origin.array_slice,
        );
        const destination_subresource_index = destination_texture.calcSubresource(
            dst.mip_level,
            destination_origin.array_slice,
        );

        std.debug.assert(copy_size.array_count == 1); // TODO

        command_list.?.ID3D12GraphicsCommandList_CopyTextureRegion(
            &.{
                .pResource = destination_texture.resource.d3d_resource,
                .Type = .SUBRESOURCE_INDEX,
                .unnamed_0 = .{
                    .SubresourceIndex = destination_subresource_index,
                },
            },
            destination_origin.x,
            destination_origin.y,
            destination_origin.z,
            &.{
                .pResource = source_texture.resource.d3d_resource,
                .Type = .SUBRESOURCE_INDEX,
                .unnamed_0 = .{
                    .SubresourceIndex = source_subresource_index,
                },
            },
            &.{
                .left = source_origin.x,
                .top = source_origin.y,
                .front = source_origin.z,
                .right = source_origin.x + copy_size.width,
                .bottom = source_origin.y + copy_size.height,
                .back = source_origin.z + copy_size.depth,
            },
        );
    }

    pub fn finish(self: *D3D12CommandEncoder, desc: *const gpu.CommandBuffer.Descriptor) gpu.CommandBuffer.Error!*D3D12CommandBuffer {
        _ = desc;

        const command_list = self.command_buffer.command_list.?;

        self.barrier_enforcer.endPass() catch return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        self.barrier_enforcer.flush(command_list);

        const hr_close = command_list.ID3D12GraphicsCommandList_Close();
        if (!d3dcommon.checkHResult(hr_close)) return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;

        return self.command_buffer;
    }

    pub fn writeTexture(
        self: *D3D12CommandEncoder,
        destination: *const gpu.ImageCopyTexture,
        data: [*]const u8,
        data_size: usize,
        data_layout: *const gpu.Texture.DataLayout,
        write_size_raw: *const gpu.Extent3D,
    ) !void {
        const command_list = self.command_buffer.command_list.?;
        const destination_texture: *D3D12Texture = @ptrCast(@alignCast(destination.texture));

        const stream = try self.command_buffer.upload(data_size);
        @memcpy(stream.map[0..data_size], data[0..data_size]);

        try self.barrier_enforcer.transition(&destination_texture.resource, .COPY_DEST);
        self.barrier_enforcer.flush(command_list);

        const write_size = gpu.util.calcExtent(
            destination_texture.dimension,
            write_size_raw.*,
        );
        const destination_origin = gpu.util.calcOrigin(
            destination_texture.dimension,
            destination.origin,
        );
        const destination_subresource_index = destination_texture.calcSubresource(
            destination.mip_level,
            destination_origin.array_slice,
        );

        std.debug.assert(write_size.array_count == 1); // TODO

        command_list.ID3D12GraphicsCommandList_CopyTextureRegion(
            &.{
                .pResource = destination_texture.resource.d3d_resource,
                .Type = .SUBRESOURCE_INDEX,
                .unnamed_0 = .{
                    .SubresourceIndex = destination_subresource_index,
                },
            },
            destination_origin.x,
            destination_origin.y,
            destination_origin.z,
            &.{
                .pResource = stream.d3d_resource,
                .Type = .PLACED_FOOTPRINT,
                .unnamed_0 = .{
                    .PlacedFootprint = .{
                        .Offset = stream.offset,
                        .Footprint = .{
                            .Format = d3dcommon.dxgiFormatForTexture(destination_texture.format),
                            .Width = write_size.width,
                            .Height = write_size.height,
                            .Depth = write_size.depth,
                            .RowPitch = data_layout.bytes_per_row,
                        },
                    },
                },
            },
            null,
        );
    }
};

pub const D3D12BarrierEnforcer = struct {
    device: *D3D12Device = undefined,
    written_set: std.AutoArrayHashMapUnmanaged(*D3D12Resource, d3d12.D3D12_RESOURCE_STATES) = .{},
    barriers: std.ArrayListUnmanaged(d3d12.D3D12_RESOURCE_BARRIER) = .{},

    pub fn init(self: *D3D12BarrierEnforcer, device: *D3D12Device) void {
        self.device = device;
    }

    pub fn deinit(self: *D3D12BarrierEnforcer) void {
        self.written_set.deinit(allocator);
        self.barriers.deinit(allocator);
    }

    pub fn transition(self: *D3D12BarrierEnforcer, resource: *D3D12Resource, new_state: d3d12.D3D12_RESOURCE_STATES) !void {
        const old_state = self.written_set.get(resource) orelse resource.read_state;

        if (old_state == .UNORDERED_ACCESS and new_state == .UNORDERED_ACCESS) {
            try self.addUnorderedAccessBarrier(resource);
        } else if (old_state != new_state) {
            try self.written_set.put(allocator, resource, new_state);
            try self.addTransitionBarrier(resource, old_state, new_state);
        }
    }

    pub fn flush(self: *D3D12BarrierEnforcer, command_list: *d3d12.ID3D12GraphicsCommandList) void {
        if (self.barriers.items.len > 0) {
            command_list.ID3D12GraphicsCommandList_ResourceBarrier(
                @intCast(self.barriers.items.len),
                self.barriers.items.ptr,
            );

            self.barriers.clearRetainingCapacity();
        }
    }

    pub fn endPass(self: *D3D12BarrierEnforcer) !void {
        var it = self.written_set.iterator();
        while (it.next()) |entry| {
            const resource = entry.key_ptr.*;
            const state = entry.value_ptr.*;

            if (state != resource.read_state) {
                try self.addTransitionBarrier(resource, state, resource.read_state);
            }
        }

        self.written_set.clearRetainingCapacity();
    }

    pub fn addUnorderedAccessBarrier(self: *D3D12BarrierEnforcer, resource: *D3D12Resource) !void {
        const barrier: d3d12.D3D12_RESOURCE_BARRIER = .{
            .Type = .UAV,
            .Flags = .NONE,
            .Anonymous = .{
                .UAV = .{
                    .pResource = resource.resource,
                },
            },
        };
        try self.barriers.append(allocator, barrier);
    }

    pub fn addTransitionBarrier(
        self: *D3D12BarrierEnforcer,
        resource: *D3D12Resource,
        old_state: d3d12.D3D12_RESOURCE_STATES,
        new_state: d3d12.D3D12_RESOURCE_STATES,
    ) !void {
        const barrier: d3d12.D3D12_RESOURCE_BARRIER = .{
            .Type = .TRANSITION,
            .Flags = .NONE,
            .Anonymous = .{
                .Transition = .{
                    .pResource = resource.resource,
                    .StateBefore = old_state,
                    .StateAfter = new_state,
                    .Subresource = d3d12.D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,
                },
            },
        };
        try self.barriers.append(allocator, barrier);
    }
};

// ComputePassEncoder
// ComputePipeline
// Device
pub fn deviceCreateBuffer(
    device: *gpu.Device,
    desc: *const gpu.Buffer.Descriptor,
) gpu.Buffer.Error!*gpu.Buffer {
    std.debug.print("creating buffer...\n", .{});
    return @ptrCast(try D3D12Buffer.init(@ptrCast(@alignCast(device)), desc));
}

pub fn deviceCreateSampler(
    device: *gpu.Device,
    desc: *const gpu.Sampler.Descriptor,
) gpu.Sampler.Error!*gpu.Sampler {
    std.debug.print("creating sampler...\n", .{});
    return @ptrCast(try D3D12Sampler.init(@ptrCast(@alignCast(device)), desc));
}

pub fn deviceCreateSwapChain(
    device: *gpu.Device,
    surface: ?*gpu.Surface,
    desc: *const gpu.SwapChain.Descriptor,
) gpu.SwapChain.Error!*gpu.SwapChain {
    std.debug.print("creating swap chain...\n", .{});
    return @ptrCast(try D3D12SwapChain.init(@ptrCast(@alignCast(device)), @ptrCast(@alignCast(surface.?)), desc));
}

pub fn deviceCreateTexture(
    device: *gpu.Device,
    desc: *const gpu.Texture.Descriptor,
) gpu.Texture.Error!*gpu.Texture {
    std.debug.print("creating texture...\n", .{});
    return @ptrCast(try D3D12Texture.init(@ptrCast(@alignCast(device)), desc));
}

pub fn deviceGetQueue(device: *gpu.Device) *gpu.Queue {
    std.debug.print("getting queue...\n", .{});
    return D3D12Device.getQueue(@ptrCast(@alignCast(device)));
}

pub fn deviceDestroy(device: *gpu.Device) void {
    std.debug.print("destroying device...\n", .{});
    D3D12Device.deinit(@alignCast(@ptrCast(device)));
}

pub const D3D12Device = struct {
    physical_device: *D3D12PhysicalDevice,
    queue: *D3D12Queue,

    device: ?*d3d12.ID3D12Device2 = null, // PhysicalDevice
    lost_cb: ?gpu.Device.LostCallback = null,

    general_heap: D3D12DescriptorHeap = undefined,
    sampler_heap: D3D12DescriptorHeap = undefined,
    rtv_heap: D3D12DescriptorHeap = undefined,
    dsv_heap: D3D12DescriptorHeap = undefined,

    command_pool: D3D12CommandPool = undefined,
    streaming_pool: D3D12StreamingPool = undefined,
    resource_pool: D3D12ResourcePool = undefined,

    pub fn init(physical_device: *D3D12PhysicalDevice, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*D3D12Device {
        const queue = allocator.create(D3D12Queue) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer allocator.destroy(queue);

        const self = allocator.create(D3D12Device) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer allocator.destroy(self);
        self.* = .{
            .physical_device = physical_device,
            .queue = queue,
            .lost_cb = desc.lost_callback,
        };

        const hr = d3d12.D3D12CreateDevice(
            @ptrCast(self.physical_device.adapter),
            .@"11_0",
            d3d12.IID_ID3D12Device2,
            @ptrCast(&self.device),
        );
        if (!d3dcommon.checkHResult(hr)) return gpu.Device.Error.DeviceFailedToCreate;
        errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12Device2, &self.device);

        if (self.physical_device.instance.debug) {
            var info_queue: ?*d3d12.ID3D12InfoQueue = null;
            if (winapi.zig.SUCCEEDED(
                self.device.?.IUnknown_QueryInterface(d3d12.IID_ID3D12InfoQueue, @ptrCast(&info_queue)),
            )) {
                defer d3dcommon.releaseIUnknown(d3d12.ID3D12InfoQueue, &info_queue);
                var deny_ids = [_]d3d12.D3D12_MESSAGE_ID{
                    d3d12.D3D12_MESSAGE_ID_CLEARRENDERTARGETVIEW_MISMATCHINGCLEARVALUE,
                    d3d12.D3D12_MESSAGE_ID_CLEARDEPTHSTENCILVIEW_MISMATCHINGCLEARVALUE,
                    d3d12.D3D12_MESSAGE_ID_CREATERESOURCE_STATE_IGNORED, // Required for naive barrier strategy, can be removed with render graphs
                };
                var severities = [_]d3d12.D3D12_MESSAGE_SEVERITY{
                    d3d12.D3D12_MESSAGE_SEVERITY_INFO,
                    d3d12.D3D12_MESSAGE_SEVERITY_MESSAGE,
                };
                var filter = d3d12.D3D12_INFO_QUEUE_FILTER{
                    .AllowList = .{
                        .NumCategories = 0,
                        .pCategoryList = null,
                        .NumSeverities = 0,
                        .pSeverityList = null,
                        .NumIDs = 0,
                        .pIDList = null,
                    },
                    .DenyList = .{
                        .NumCategories = 0,
                        .pCategoryList = null,
                        .NumSeverities = severities.len,
                        .pSeverityList = @ptrCast(&severities),
                        .NumIDs = deny_ids.len,
                        .pIDList = @ptrCast(&deny_ids),
                    },
                };

                const push_hr = info_queue.?.ID3D12InfoQueue_PushStorageFilter(
                    &filter,
                );
                _ = push_hr;
            }
        }

        self.queue.* = D3D12Queue.init(self) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer D3D12Queue.deinit(queue);

        // TODO: heaps

        self.general_heap = D3D12DescriptorHeap.init(
            self,
            .CBV_SRV_UAV,
            .SHADER_VISIBLE,
            general_heap_size,
            general_block_size,
        ) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer self.general_heap.deinit();

        self.sampler_heap = D3D12DescriptorHeap.init(
            self,
            .SAMPLER,
            .SHADER_VISIBLE,
            sampler_heap_size,
            sampler_block_size,
        ) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer self.sampler_heap.deinit();

        self.rtv_heap = D3D12DescriptorHeap.init(
            self,
            .RTV,
            .NONE,
            rtv_heap_size,
            rtv_block_size,
        ) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer self.rtv_heap.deinit();

        self.dsv_heap = D3D12DescriptorHeap.init(
            self,
            .DSV,
            .NONE,
            dsv_heap_size,
            dsv_block_size,
        ) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer self.dsv_heap.deinit();

        self.command_pool = D3D12CommandPool.init(self);
        self.streaming_pool = D3D12StreamingPool.init(self);
        self.resource_pool = D3D12ResourcePool.init(self);

        return self;
    }

    pub fn deinit(self: *D3D12Device) void {
        if (self.lost_cb) |cb| {
            cb(.destroyed, "device destroyed");
        }
        _ = self.queue.waitUntil(self.queue.fence_value);

        self.command_pool.deinit();
        self.streaming_pool.deinit();
        self.resource_pool.deinit();

        self.dsv_heap.deinit();
        self.rtv_heap.deinit();
        self.sampler_heap.deinit();
        self.general_heap.deinit();

        self.queue.deinit();
        allocator.destroy(self.queue);
        d3dcommon.releaseIUnknown(d3d12.ID3D12Device2, &self.device);
        allocator.destroy(self);
    }

    pub fn getQueue(self: *D3D12Device) *gpu.Queue {
        return @ptrCast(@alignCast(self.queue));
    }

    // internal
    pub fn createD3dBuffer(self: *D3D12Device, usage: gpu.Buffer.UsageFlags, size: u64) !D3D12Resource {
        const resource_size = if (usage.uniform) gpu.util.alignUp(size, 256) else size;

        const heap_type = if (usage.map_write)
            d3d12.D3D12_HEAP_TYPE_UPLOAD
        else if (usage.map_read)
            d3d12.D3D12_HEAP_TYPE_READBACK
        else
            d3d12.D3D12_HEAP_TYPE_DEFAULT;

        const heap_properties = d3d12.D3D12_HEAP_PROPERTIES{
            .Type = heap_type,
            .CPUPageProperty = .UNKNOWN,
            .MemoryPoolPreference = .UNKNOWN,
            .CreationNodeMask = 1,
            .VisibleNodeMask = 1,
        };
        const resource_desc = d3d12.D3D12_RESOURCE_DESC{
            .Dimension = .BUFFER,
            .Alignment = 0,
            .Width = resource_size,
            .Height = 1,
            .DepthOrArraySize = 1,
            .MipLevels = 1,
            .Format = dxgi.common.DXGI_FORMAT_UNKNOWN,
            .SampleDesc = .{
                .Count = 1,
                .Quality = 0,
            },
            .Layout = d3d12.D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            .Flags = if (usage.storage)
                d3d12.D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS
            else
                d3d12.D3D12_RESOURCE_FLAG_NONE,
        };

        const read_state = d3d12.D3D12_RESOURCE_STATES.initFlags(.{
            .COPY_SOURCE = if (usage.copy_src) 1 else 0,
            .INDEX_BUFFER = if (usage.index) 1 else 0,
            .VERTEX_AND_CONSTANT_BUFFER = if (usage.uniform or usage.vertex) 1 else 0,
            .ALL_SHADER_RESOURCE = if (usage.storage) 1 else 0,
            .INDIRECT_ARGUMENT = if (usage.indirect) 1 else 0,
        });
        const initial_state: d3d12.D3D12_RESOURCE_STATES = switch (heap_type) {
            .UPLOAD => .GENERIC_READ,
            .READBACK => .COPY_DEST,
            else => read_state,
        };

        var resource: ?*d3d12.ID3D12Resource = null;
        const resource_hr = self.device.?.ID3D12Device_CreateCommittedResource(
            &heap_properties,
            .CREATE_NOT_ZEROED,
            &resource_desc,
            initial_state,
            null,
            d3d12.IID_ID3D12Resource,
            @ptrCast(&resource),
        );
        if (!d3dcommon.checkHResult(resource_hr)) return D3D12Resource.Error.ResourceFailedToCreate;
        errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, &resource);

        return .{
            .resource = resource,
            .read_state = read_state,
        };
    }
};

pub const D3D12StreamingPool = struct {
    device: *D3D12Device,
    free_buffers: std.ArrayListUnmanaged(*d3d12.ID3D12Resource) = .{},

    pub fn init(device: *D3D12Device) D3D12StreamingPool {
        return .{
            .device = device,
        };
    }

    pub fn deinit(manager: *D3D12StreamingPool) void {
        for (manager.free_buffers.items) |resource| {
            var proxy: ?*d3d12.ID3D12Resource = resource;
            d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, &proxy);
        }
        manager.free_buffers.deinit(allocator);
    }

    pub fn acquire(self: *D3D12StreamingPool) !*d3d12.ID3D12Resource {
        // Create new buffer
        if (self.free_buffers.items.len == 0) {
            var resource = try self.device.createD3dBuffer(.{ .map_write = true }, upload_page_size);
            errdefer resource.deinit();

            try self.free_buffers.append(allocator, resource.d3d_resource);
        }

        // Result
        return self.free_buffers.pop();
    }

    pub fn release(self: *D3D12StreamingPool, d3d_resource: *d3d12.ID3D12Resource) void {
        self.free_buffers.append(allocator, d3d_resource) catch {
            @panic("failed to release streaming buffer");
        };
    }
};

pub const D3D12DescriptorHeap = struct {
    pub const Error = error{
        DescriptorHeapFailedToCreate,
        DescriptorHeapOutOfMemory,
    };
    pub const Allocation = u32;

    device: *D3D12Device,
    heap: ?*d3d12.ID3D12DescriptorHeap = null,
    cpu_handle: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE,
    gpu_handle: d3d12.D3D12_GPU_DESCRIPTOR_HANDLE,
    descriptor_size: u32,
    descriptor_count: u32,
    block_size: u32,
    next_alloc: u32,
    free_blocks: std.ArrayListUnmanaged(Allocation) = .{},

    pub fn init(
        device: *D3D12Device,
        heap_type: d3d12.D3D12_DESCRIPTOR_HEAP_TYPE,
        flags: d3d12.D3D12_DESCRIPTOR_HEAP_FLAGS,
        descriptor_count: u32,
        block_size: u32,
    ) !D3D12DescriptorHeap {
        var heap: ?*d3d12.ID3D12DescriptorHeap = null;
        const heap_hr = device.device.?.ID3D12Device_CreateDescriptorHeap(
            &.{
                .Type = heap_type,
                .NumDescriptors = descriptor_count,
                .Flags = flags,
                .NodeMask = 0,
            },
            d3d12.IID_ID3D12DescriptorHeap,
            @ptrCast(&heap),
        );
        if (!d3dcommon.checkHResult(heap_hr)) return Error.DescriptorHeapFailedToCreate;
        errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &heap);

        const descriptor_size = device.device.?.ID3D12Device_GetDescriptorHandleIncrementSize(heap_type);
        var cpu_handle: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE = undefined;

        const getCpuDescriptorHandleForHeapStart: (*const fn (
            self: *const d3d12.ID3D12DescriptorHeap,
            out_handle: *d3d12.D3D12_CPU_DESCRIPTOR_HANDLE,
        ) callconv(.Win64) d3d12.D3D12_CPU_DESCRIPTOR_HANDLE) = @ptrCast(heap.?.vtable.GetCPUDescriptorHandleForHeapStart);
        _ = getCpuDescriptorHandleForHeapStart(heap.?, &cpu_handle);

        var gpu_handle: d3d12.D3D12_GPU_DESCRIPTOR_HANDLE = undefined;
        if (@intFromEnum(flags) & @intFromEnum(d3d12.D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE) != 0) {
            const getGpuDescriptorHandleForHeapStart: (*const fn (
                self: *const d3d12.ID3D12DescriptorHeap,
                out_handle: *d3d12.D3D12_GPU_DESCRIPTOR_HANDLE,
            ) callconv(.Win64) d3d12.D3D12_GPU_DESCRIPTOR_HANDLE) = @ptrCast(heap.?.vtable.GetGPUDescriptorHandleForHeapStart);

            gpu_handle = getGpuDescriptorHandleForHeapStart(heap.?, &gpu_handle);
        } else {
            gpu_handle = .{ .ptr = 0 };
        }

        return .{
            .device = device,
            .heap = heap,
            .cpu_handle = cpu_handle,
            .gpu_handle = gpu_handle,
            .descriptor_size = descriptor_size,
            .descriptor_count = descriptor_count,
            .block_size = block_size,
            .next_alloc = 0,
        };
    }

    pub fn deinit(self: *D3D12DescriptorHeap) void {
        self.free_blocks.deinit(allocator);
        d3dcommon.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &self.heap);
    }

    pub fn alloc(heap: *D3D12DescriptorHeap) !Allocation {
        if (heap.free_blocks.getLastOrNull() == null) {
            if (heap.next_alloc == heap.descriptor_count) {
                return Error.DescriptorHeapOutOfMemory;
            }
            const index = heap.next_alloc;
            heap.next_alloc += heap.block_size;
            try heap.free_blocks.append(index);
        }

        return heap.free_blocks.pop();
    }

    pub fn free(heap: *D3D12DescriptorHeap, allocation: Allocation) void {
        heap.free_blocks.append(allocation) catch {
            @panic("failed to free descriptor heap allocation");
        };
    }

    pub fn cpuDescriptor(self: *D3D12DescriptorHeap, index: u32) d3d12.D3D12_CPU_DESCRIPTOR_HANDLE {
        return .{
            .ptr = self.cpu_handle.ptr + index * self.descriptor_size,
        };
    }

    pub fn gpuDescriptor(self: *D3D12DescriptorHeap, index: u32) d3d12.D3D12_GPU_DESCRIPTOR_HANDLE {
        return .{
            .ptr = self.gpu_handle.ptr + index * self.descriptor_size,
        };
    }
};

pub const D3D12Resource = struct {
    pub const Error = error{
        ResourceFailedToCreate,
    };

    resource: ?*d3d12.ID3D12Resource = null,
    read_state: d3d12.D3D12_RESOURCE_STATES,

    pub fn deinit(self: *D3D12Resource) void {
        d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, &self.resource);
    }
};

// Instance
pub fn createInstance(alloc: std.mem.Allocator, desc: *const gpu.Instance.Descriptor) gpu.Instance.Error!*gpu.Instance {
    std.debug.print("creating instance...\n", .{});
    return @ptrCast(D3D12Instance.init(alloc, desc) catch
        return gpu.Instance.Error.InstanceFailedToCreate);
}

pub fn instanceCreateSurface(
    instance: *gpu.Instance,
    desc: *const gpu.Surface.Descriptor,
) gpu.Surface.Error!*gpu.Surface {
    std.debug.print("creating surface...\n", .{});
    return @ptrCast(try D3D12Surface.init(@ptrCast(@alignCast(instance)), desc));
}

pub fn instanceRequestPhysicalDevice(
    instance: *gpu.Instance,
    options: *const gpu.PhysicalDevice.Options,
) gpu.PhysicalDevice.Error!*gpu.PhysicalDevice {
    std.debug.print("requesting physical_device...\n", .{});
    return @ptrCast(try D3D12PhysicalDevice.init(@ptrCast(@alignCast(instance)), options));
}

pub fn instanceDestroy(instance: *gpu.Instance) void {
    std.debug.print("destroying instance...\n", .{});
    D3D12Instance.deinit(@alignCast(@ptrCast(instance)));
}

var allocator: std.mem.Allocator = undefined;
pub const D3D12Instance = struct {
    factory: ?*dxgi.IDXGIFactory6 = null,
    debug_layer: ?*d3d12.ID3D12Debug = null,
    debug: bool,
    allow_tearing: bool = false,

    pub fn init(alloc: std.mem.Allocator, desc: *const gpu.Instance.Descriptor) gpu.Instance.Error!*D3D12Instance {
        allocator = alloc;
        const self = allocator.create(D3D12Instance) catch return gpu.Instance.Error.InstanceFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .debug = desc.debug,
        };

        if (self.debug) {
            const hr_debug = d3d12.D3D12GetDebugInterface(
                d3d12.IID_ID3D12Debug,
                @ptrCast(&self.debug_layer),
            );
            if (!d3dcommon.checkHResult(hr_debug)) return gpu.Instance.Error.InstanceFailedToCreate;
            errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12Debug, &self.debug_layer);
            self.debug_layer.?.ID3D12Debug_EnableDebugLayer();
        }

        const hr_factory = dxgi.CreateDXGIFactory2(
            if (desc.debug) dxgi.DXGI_CREATE_FACTORY_DEBUG else 0,
            dxgi.IID_IDXGIFactory6,
            @ptrCast(&self.factory),
        );
        if (!d3dcommon.checkHResult(hr_factory)) return gpu.Instance.Error.InstanceFailedToCreate;

        if (winapi.zig.FAILED(self.factory.?.IDXGIFactory5_CheckFeatureSupport(
            dxgi.DXGI_FEATURE_PRESENT_ALLOW_TEARING,
            &self.allow_tearing,
            @sizeOf(@TypeOf(&self.allow_tearing)),
        ))) {
            self.allow_tearing = false;
        }

        return self;
    }

    pub fn deinit(self: *D3D12Instance) void {
        d3dcommon.releaseIUnknown(dxgi.IDXGIFactory6, &self.factory);
        d3dcommon.releaseIUnknown(d3d12.ID3D12Debug, &self.debug_layer);
        allocator.destroy(self);
    }
};

// PhysicalDevice
pub fn physicalDeviceCreateDevice(
    physical_device: *gpu.PhysicalDevice,
    desc: *const gpu.Device.Descriptor,
) gpu.Device.Error!*gpu.Device {
    std.debug.print("creating device...\n", .{});
    return @ptrCast(try D3D12Device.init(@ptrCast(@alignCast(physical_device)), desc));
}

pub fn physicalDeviceGetProperties(physical_device: *gpu.PhysicalDevice, out_props: *gpu.PhysicalDevice.Properties) bool {
    return D3D12PhysicalDevice.getProperties(@ptrCast(@alignCast(physical_device)), out_props);
}

pub fn physicalDeviceDestroy(physical_device: *gpu.PhysicalDevice) void {
    std.debug.print("destroying physical_device...\n", .{});
    D3D12PhysicalDevice.deinit(@alignCast(@ptrCast(physical_device)));
}

pub const D3D12PhysicalDevice = struct {
    instance: *D3D12Instance,
    adapter: ?*dxgi.IDXGIAdapter = null,
    adapter_desc: dxgi.DXGI_ADAPTER_DESC = undefined,
    properties: gpu.PhysicalDevice.Properties = undefined,

    pub fn init(instance: *D3D12Instance, options: *const gpu.PhysicalDevice.Options) gpu.PhysicalDevice.Error!*D3D12PhysicalDevice {
        const self = allocator.create(D3D12PhysicalDevice) catch return gpu.PhysicalDevice.Error.PhysicalDeviceFailedToCreate;
        errdefer self.deinit();
        self.* = .{
            .instance = instance,
        };

        const pref = d3dcommon.mapPowerPreference(options.power_preference);
        const hr_enum = self.instance.factory.?.IDXGIFactory6_EnumAdapterByGpuPreference(
            0,
            pref,
            dxgi.IID_IDXGIAdapter,
            @ptrCast(&self.adapter),
        );

        // get a description of the adapter
        _ = self.adapter.?.IDXGIAdapter_GetDesc(&self.adapter_desc);

        var scratch = common.ScratchSpace(4096){};
        const temp_allocator = scratch.init().allocator();

        const converted_description = std.unicode.utf16leToUtf8Alloc(
            temp_allocator,
            &self.adapter_desc.Description,
        ) catch "<unknown>";

        self.properties.name = allocator.dupe(u8, converted_description) catch
            return gpu.PhysicalDevice.Error.PhysicalDeviceFailedToCreate;
        errdefer allocator.free(converted_description);
        self.properties.vendor = @enumFromInt(self.adapter_desc.VendorId);
        if (!d3dcommon.checkHResult(hr_enum)) return gpu.PhysicalDevice.Error.PhysicalDeviceFailedToCreate;

        return self;
    }

    pub fn deinit(self: *D3D12PhysicalDevice) void {
        allocator.free(self.properties.name);
        d3dcommon.releaseIUnknown(dxgi.IDXGIAdapter, &self.adapter);
        allocator.destroy(self);
    }

    pub fn getProperties(self: *D3D12PhysicalDevice, out_props: *gpu.PhysicalDevice.Properties) bool {
        out_props.* = self.properties;
        return true;
    }
};

// PipelineLayout
// QuerySet
// Queue
pub fn queueSubmit(queue: *gpu.Queue, command_buffers: []const *gpu.CommandBuffer) gpu.Queue.Error!void {
    std.debug.print("submitting queue...\n", .{});
    try D3D12Queue.submit(@ptrCast(@alignCast(queue)), command_buffers);
}

pub const D3D12Queue = struct {
    device: *D3D12Device,
    command_queue: ?*d3d12.ID3D12CommandQueue = null,

    fence: ?*d3d12.ID3D12Fence,
    fence_value: u64 = 0,
    fence_event: win32.foundation.HANDLE = undefined,
    current_command_encoder: ?*D3D12CommandEncoder = null,

    // Assigned to a pointer, so it doesn't need to allocate
    pub fn init(device: *D3D12Device) gpu.Queue.Error!D3D12Queue {
        const command_queue_desc: d3d12.D3D12_COMMAND_QUEUE_DESC = .{
            .Type = .DIRECT,
            .Priority = @intFromEnum(d3d12.D3D12_COMMAND_QUEUE_PRIORITY_NORMAL),
            .Flags = d3d12.D3D12_COMMAND_QUEUE_FLAG_NONE,
            .NodeMask = 0,
        };
        var command_queue: ?*d3d12.ID3D12CommandQueue = null;
        const hr_command_queue = device.device.?.ID3D12Device_CreateCommandQueue(
            &command_queue_desc,
            d3d12.IID_ID3D12CommandQueue,
            @ptrCast(&command_queue),
        );
        if (!d3dcommon.checkHResult(hr_command_queue)) return gpu.Queue.Error.QueueFailedToCreate;
        errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12CommandQueue, &command_queue);

        var fence: ?*d3d12.ID3D12Fence = null;
        const hr_fence = device.device.?.ID3D12Device_CreateFence(
            0,
            d3d12.D3D12_FENCE_FLAG_NONE,
            d3d12.IID_ID3D12Fence,
            @ptrCast(&fence),
        );
        if (!d3dcommon.checkHResult(hr_fence)) return gpu.Queue.Error.QueueFailedToCreate;
        errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12Fence, &fence);

        const fence_event = win32.system.threading.CreateEventW(
            null,
            FALSE,
            FALSE,
            null,
        );
        if (fence_event == null) return gpu.Queue.Error.QueueFailedToCreate;
        errdefer _ = win32.foundation.CloseHandle(fence_event);

        return .{
            .device = device,
            .command_queue = command_queue,
            .fence = fence,
            .fence_event = fence_event.?,
        };
    }

    pub fn deinit(self: *D3D12Queue) void {
        if (self.current_command_encoder) |ce| ce.deinit();
        d3dcommon.releaseIUnknown(d3d12.ID3D12CommandQueue, &self.command_queue);
        d3dcommon.releaseIUnknown(d3d12.ID3D12Fence, &self.fence);
        _ = win32.foundation.CloseHandle(self.fence_event);
    }

    pub fn submit(self: *D3D12Queue, command_buffers: []const *gpu.CommandBuffer) gpu.Queue.Error!void {
        var scratch = common.ScratchSpace(4096){};
        const temp_allocator = scratch.init().allocator();

        var command_lists = std.ArrayListUnmanaged(
            *d3d12.ID3D12GraphicsCommandList,
        ).initCapacity(
            temp_allocator,
            command_buffers.len + 1,
        ) catch unreachable;
        defer command_lists.deinit(temp_allocator);

        self.fence_value += 1;

        if (self.current_command_encoder) |ce| {
            const command_buffer = ce.finish(&.{}) catch return gpu.Queue.Error.QueueFailedToSubmit;
            command_lists.appendAssumeCapacity(command_buffer.command_list.?);
            ce.deinit();
            self.current_command_encoder = null;
        }

        for (command_buffers) |cb| {
            const command_buffer: *D3D12CommandBuffer = @ptrCast(@alignCast(cb));
            command_lists.appendAssumeCapacity(command_buffer.command_list.?);
        }

        self.command_queue.?.ID3D12CommandQueue_ExecuteCommandLists(
            @intCast(command_lists.items.len),
            @ptrCast(command_lists.items.ptr),
        );

        for (command_lists.items) |cl| {
            self.device.command_pool.destroyCommandList(cl);
        }

        self.signal() catch return gpu.Queue.Error.QueueFailedToSubmit;
    }

    // internal
    pub fn signal(self: *D3D12Queue) gpu.Queue.Error!void {
        const hr = self.command_queue.?.ID3D12CommandQueue_Signal(
            @ptrCast(self.fence),
            self.fence_value,
        );
        if (!d3dcommon.checkHResult(hr)) return gpu.Queue.Error.QueueFailedToSubmit;
    }

    pub fn waitUntil(self: *D3D12Queue, value: u64) bool {
        // check if completed
        const completed_value = self.fence.?.ID3D12Fence_GetCompletedValue();
        if (completed_value >= value) return true;

        const event_hr = self.fence.?.ID3D12Fence_SetEventOnCompletion(value, self.fence_event);
        if (!d3dcommon.checkHResult(event_hr)) return false;

        const wait_result = win32.system.threading.WaitForSingleObject(
            self.fence_event,
            win32.system.threading.INFINITE,
        );
        if (wait_result != .OBJECT_0) return false;
        return true;
    }

    pub fn getCommandEncoder(self: *D3D12Queue) !*D3D12CommandEncoder {
        if (self.current_command_encoder) |ce| {
            return ce;
        }

        const ce = try D3D12CommandEncoder.init(self.device, &.{});
        self.current_command_encoder = ce;
        return ce;
    }
};

pub const D3D12CommandPool = struct {
    const Error = error{
        CommandPoolResetAllocatorFailed,
        CommandPoolResetListFailed,
    };

    device: *D3D12Device,
    free_allocators: std.ArrayListUnmanaged(*d3d12.ID3D12CommandAllocator),
    free_command_lists: std.ArrayListUnmanaged(*d3d12.ID3D12GraphicsCommandList),

    pub fn init(device: *D3D12Device) D3D12CommandPool {
        return .{
            .device = device,
            .free_allocators = .{},
            .free_command_lists = .{},
        };
    }

    pub fn deinit(self: *D3D12CommandPool) void {
        for (self.free_allocators.items) |al| {
            var proxy: ?*d3d12.ID3D12CommandAllocator = al;
            d3dcommon.releaseIUnknown(d3d12.ID3D12CommandAllocator, &proxy);
        }
        for (self.free_command_lists.items) |command_list| {
            var proxy: ?*d3d12.ID3D12GraphicsCommandList = command_list;
            d3dcommon.releaseIUnknown(d3d12.ID3D12GraphicsCommandList, &proxy);
        }

        self.free_allocators.deinit(allocator);
        self.free_command_lists.deinit(allocator);
    }

    pub fn createCommandAllocator(self: *D3D12CommandPool) !*d3d12.ID3D12CommandAllocator {
        if (self.free_allocators.getLastOrNull() == null) {
            var command_allocator: ?*d3d12.ID3D12CommandAllocator = null;
            const command_allocator_hr = self.device.device.?.ID3D12Device_CreateCommandAllocator(
                .DIRECT,
                d3d12.IID_ID3D12CommandAllocator,
                @ptrCast(&command_allocator),
            );
            if (!d3dcommon.checkHResult(command_allocator_hr)) return Error.CommandPoolResetAllocatorFailed;
            try self.free_allocators.append(allocator, command_allocator.?);
        }

        const command_allocator = self.free_allocators.pop();
        const reset_hr = command_allocator.ID3D12CommandAllocator_Reset();
        if (!d3dcommon.checkHResult(reset_hr)) return Error.CommandPoolResetAllocatorFailed;
        return command_allocator;
    }

    pub fn destroyCommandAllocator(self: *D3D12CommandPool, command_allocator: *d3d12.ID3D12CommandAllocator) void {
        self.free_allocators.append(allocator, command_allocator) catch {
            @panic("failed to destroy command allocator");
        };
    }

    pub fn createCommandList(
        self: *D3D12CommandPool,
        command_allocator: ?*d3d12.ID3D12CommandAllocator,
    ) !*d3d12.ID3D12GraphicsCommandList {
        if (self.free_command_lists.getLastOrNull() == null) {
            var command_list: ?*d3d12.ID3D12GraphicsCommandList = null;
            const command_list_hr = self.device.device.?.ID3D12Device_CreateCommandList(
                0,
                .DIRECT,
                command_allocator,
                null,
                d3d12.IID_ID3D12GraphicsCommandList,
                @ptrCast(&command_list),
            );
            if (!d3dcommon.checkHResult(command_list_hr)) return Error.CommandPoolResetListFailed;

            return command_list.?;
        }

        const command_list = self.free_command_lists.pop();
        const reset_hr = command_list.ID3D12GraphicsCommandList_Reset(
            command_allocator,
            null,
        );
        if (!d3dcommon.checkHResult(reset_hr)) return Error.CommandPoolResetListFailed;
        return command_list;
    }

    pub fn destroyCommandList(self: *D3D12CommandPool, command_list: *d3d12.ID3D12GraphicsCommandList) void {
        self.free_command_lists.append(allocator, command_list) catch {
            @panic("failed to destroy command list");
        };
    }
};

pub const D3D12ResourcePool = struct {
    device: *D3D12Device,
    free_resources: std.ArrayListUnmanaged(*d3d12.ID3D12Resource),

    pub fn init(device: *D3D12Device) D3D12ResourcePool {
        return .{
            .device = device,
            .free_resources = .{},
        };
    }

    pub fn deinit(self: *D3D12ResourcePool) void {
        for (self.free_resources.items) |resource| {
            var proxy: ?*d3d12.ID3D12Resource = resource;
            d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, &proxy);
        }
        self.free_resources.deinit(allocator);
    }

    pub fn acquirePage(self: *D3D12ResourcePool) !d3d12.ID3D12Resource {
        if (self.free_resources.getLastOrNull() == null) {
            const resource = try self.device.createD3dBuffer(
                .{
                    .map_write = true,
                },
                upload_page_size,
            );
            errdefer resource.deinit();

            try self.free_resources.append(allocator, resource.resource) catch {
                @panic("failed to allocate resource");
            };
        }

        return self.free_resources.pop();
    }

    pub fn releasePage(self: *D3D12ResourcePool, resource: *d3d12.ID3D12Resource) void {
        self.free_resources.append(allocator, resource) catch {
            @panic("failed to destroy resource");
        };
    }
};
// RenderBundle
// RenderBundleEncoder
// RenderPassEncoder
// RenderPipeline

// Sampler
pub fn samplerDestroy(sampler: *gpu.Sampler) void {
    std.debug.print("destroying sampler...\n", .{});
    D3D12Sampler.deinit(@alignCast(@ptrCast(sampler)));
}

pub const D3D12Sampler = struct {
    desc: d3d12.D3D12_SAMPLER_DESC,

    fn d3d12TextureAddressMode(address_mode: gpu.Sampler.AddressMode) d3d12.D3D12_TEXTURE_ADDRESS_MODE {
        return switch (address_mode) {
            .repeat => .WRAP,
            .mirror_repeat => .MIRROR,
            .clamp_to_edge => .CLAMP,
        };
    }

    fn d3d12FilterType(filter: gpu.FilterMode) d3d12.D3D12_FILTER_TYPE {
        return switch (filter) {
            .nearest => .POINT,
            .linear => .LINEAR,
        };
    }

    fn d3d12FilterTypeForMipmap(filter: gpu.MipmapFilterMode) d3d12.D3D12_FILTER_TYPE {
        return switch (filter) {
            .nearest => .POINT,
            .linear => .LINEAR,
        };
    }

    fn d3d12Filter(
        mag_filter: gpu.FilterMode,
        min_filter: gpu.FilterMode,
        mipmap_filter: gpu.MipmapFilterMode,
        max_anisotropy: u16,
    ) d3d12.D3D12_FILTER {
        var filter: i32 = 0;
        filter |= d3d12FilterType(min_filter) << d3d12.D3D12_MIN_FILTER_SHIFT;
        filter |= d3d12FilterType(mag_filter) << d3d12.D3D12_MAG_FILTER_SHIFT;
        filter |= d3d12FilterTypeForMipmap(mipmap_filter) << d3d12.D3D12_MIP_FILTER_SHIFT;
        filter |= @intFromEnum(
            d3d12.D3D12_FILTER_REDUCTION_TYPE_STANDARD,
        ) << d3d12.D3D12_FILTER_REDUCTION_TYPE_SHIFT;
        if (max_anisotropy > 1)
            filter |= d3d12.D3D12_ANISOTROPIC_FILTERING_BIT;
        return @enumFromInt(filter);
    }

    pub fn init(device: *D3D12Device, desc: *const gpu.Sampler.Descriptor) gpu.Sampler.Error!*D3D12Sampler {
        _ = device;
        const d3d_desc = d3d12.D3D12_SAMPLER_DESC{
            .Filter = d3d12Filter(
                desc.mag_filter,
                desc.min_filter,
                desc.mipmap_filter,
                desc.max_anisotropy,
            ),
            .AddressU = d3d12TextureAddressMode(desc.address_mode_u),
            .AddressV = d3d12TextureAddressMode(desc.address_mode_v),
            .AddressW = d3d12TextureAddressMode(desc.address_mode_w),
            .MipLODBias = 0.0,
            .MaxAnisotropy = desc.max_anisotropy,
            .ComparisonFunc = if (desc.compare != .undefined) d3d12ComparisonFunc(desc.compare) else .NEVER,
            .BorderColor = .{ 0.0, 0.0, 0.0, 0.0 },
            .MinLOD = desc.lod_min_clamp,
            .MaxLOD = desc.lod_max_clamp,
        };

        const self = allocator.create(D3D12Sampler) catch return gpu.Sampler.Error.SamplerFailedToCreate;
        self.* = .{
            .desc = d3d_desc,
        };
        return self;
    }

    pub fn deinit(self: *D3D12Sampler) void {
        allocator.destroy(self);
    }
};

pub fn d3d12ComparisonFunc(func: gpu.CompareFunction) d3d12.D3D12_COMPARISON_FUNC {
    return switch (func) {
        .undefined => unreachable,
        .never => .NEVER,
        .less => .LESS,
        .less_equal => .LESS_EQUAL,
        .greater => .GREATER,
        .greater_equal => .GREATER_EQUAL,
        .equal => .EQUAL,
        .not_equal => .NOT_EQUAL,
        .always => .ALWAYS,
    };
}

// ShaderModule
// Surface
pub fn surfaceDestroy(surface: *gpu.Surface) void {
    std.debug.print("destroying surface...\n", .{});
    D3D12Surface.deinit(@alignCast(@ptrCast(surface)));
}

pub const D3D12Surface = struct {
    hwnd: ?win32.foundation.HWND = null,

    pub fn init(instance: *D3D12Instance, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*D3D12Surface {
        _ = instance;
        const self = allocator.create(D3D12Surface) catch return gpu.Surface.Error.SurfaceFailedToCreate;
        self.* = .{
            .hwnd = desc.native_handle,
        };
        return self;
    }

    pub fn deinit(self: *D3D12Surface) void {
        allocator.destroy(self);
    }
};

// SwapChain
pub fn swapChainGetCurrentTexture(
    swapchain: *gpu.SwapChain,
) ?*gpu.Texture {
    _ = swapchain;
    std.debug.print("getting swapchain texture is unimplemented...\n", .{});
    return null;
}

pub fn swapChainGetCurrentTextureView(
    swapchain: *gpu.SwapChain,
) ?*gpu.TextureView {
    std.debug.print("getting swapchain texture view...\n", .{});
    return @ptrCast(@alignCast(try D3D12SwapChain.getCurrentTextureView(@ptrCast(@alignCast(swapchain)))));
}

pub fn swapChainPresent(swapchain: *gpu.SwapChain) !void {
    D3D12SwapChain.present(@ptrCast(@alignCast(swapchain))) catch {};
}

pub fn swapChainResize(
    swapchain: *gpu.SwapChain,
    size: [2]u32,
) gpu.SwapChain.Error!void {
    D3D12SwapChain.resize(@ptrCast(@alignCast(swapchain)), size) catch {};
}

pub fn swapChainDestroy(swapchain: *gpu.SwapChain) void {
    std.debug.print("destroying swapchain...\n", .{});
    D3D12SwapChain.deinit(@alignCast(@ptrCast(swapchain)));
}

pub const D3D12SwapChain = struct {
    device: *D3D12Device,

    swapchain: ?*dxgi.IDXGISwapChain4 = null,

    buffer_count: u32,
    textures: [3]?*D3D12Texture = .{ null, null, null },
    views: [3]?*D3D12TextureView = .{ null, null, null },
    fences: [3]u64 = .{ 0, 0, 0 },

    current_index: u32 = 0,

    sync_interval: u32,
    present_flags: u32,
    desc: gpu.SwapChain.Descriptor = undefined,

    pub fn init(
        device: *D3D12Device,
        surface: *D3D12Surface,
        desc: *const gpu.SwapChain.Descriptor,
    ) gpu.SwapChain.Error!*D3D12SwapChain {
        const buffer_count: u32 = if (desc.present_mode == .mailbox) 3 else 2;

        var swapchain_desc: dxgi.DXGI_SWAP_CHAIN_DESC1 = undefined;
        swapchain_desc.Width = desc.width;
        swapchain_desc.Height = desc.height;
        swapchain_desc.Format = d3dcommon.dxgiFormatForTexture(desc.format);
        swapchain_desc.Stereo = FALSE;
        swapchain_desc.SampleDesc = .{
            .Count = 1,
            .Quality = 0,
        };
        swapchain_desc.BufferUsage = .RENDER_TARGET_OUTPUT;
        swapchain_desc.BufferCount = buffer_count;
        swapchain_desc.Scaling = .STRETCH;
        swapchain_desc.SwapEffect = .FLIP_DISCARD;
        swapchain_desc.AlphaMode = .UNSPECIFIED;
        swapchain_desc.Flags = if (device.physical_device.instance.allow_tearing)
            @intFromEnum(dxgi.DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING)
        else
            0;

        var swapchain: ?*dxgi.IDXGISwapChain4 = null;
        const hr_swapchain = device.physical_device.instance.factory.?.IDXGIFactory2_CreateSwapChainForHwnd(
            @ptrCast(device.queue.command_queue),
            surface.hwnd,
            &swapchain_desc,
            null,
            null,
            @ptrCast(&swapchain),
        );
        if (!d3dcommon.checkHResult(hr_swapchain)) return gpu.SwapChain.Error.SwapChainFailedToCreate;
        errdefer d3dcommon.releaseIUnknown(dxgi.IDXGISwapChain4, &swapchain);

        const self = allocator.create(D3D12SwapChain) catch return gpu.SwapChain.Error.SwapChainFailedToCreate;
        self.* = .{
            .device = device,
            .swapchain = swapchain,
            .buffer_count = buffer_count,
            .sync_interval = if (desc.present_mode == .immediate) 0 else 1,
            .present_flags = if (desc.present_mode == .immediate and device.physical_device.instance.allow_tearing)
                dxgi.DXGI_PRESENT_ALLOW_TEARING
            else
                0,
            .desc = desc.*,
        };

        self.createRenderTargets() catch return gpu.SwapChain.Error.SwapChainFailedToCreate;

        return self;
    }

    pub fn deinit(self: *D3D12SwapChain) void {
        self.releaseRenderTargets();

        _ = self.device.queue.waitUntil(self.device.queue.fence_value);
        d3dcommon.releaseIUnknown(dxgi.IDXGISwapChain4, &self.swapchain);
        allocator.destroy(self);
    }

    fn createRenderTargets(self: *D3D12SwapChain) !void {
        var textures: [3]?*D3D12Texture = undefined;
        var views: [3]?*D3D12TextureView = undefined;
        var fences: [3]u64 = undefined;

        for (0..self.buffer_count) |index| {
            var buffer: ?*d3d12.ID3D12Resource = null;
            const buffer_hr = self.swapchain.?.IDXGISwapChain_GetBuffer(
                @intCast(index),
                d3d12.IID_ID3D12Resource,
                @ptrCast(&buffer),
            );
            if (!d3dcommon.checkHResult(buffer_hr)) return gpu.SwapChain.Error.SwapChainFailedToCreate;

            const texture = D3D12Texture.initSwapChain(
                self.device,
                &self.desc,
                buffer,
            ) catch return gpu.SwapChain.Error.SwapChainFailedToCreate;
            const view = texture.createView(&.{}) catch return gpu.SwapChain.Error.SwapChainFailedToCreate;

            textures[index] = texture;
            views[index] = view;
            fences[index] = 0;
        }

        self.textures = textures;
        self.views = views;
        self.fences = fences;
    }

    fn releaseRenderTargets(self: *D3D12SwapChain) void {
        _ = self.device.queue.waitUntil(self.device.queue.fence_value);

        for (self.views[0..self.buffer_count]) |*view| {
            if (view.*) |v| {
                v.deinit();
                view.* = null;
            }
        }
        for (self.textures[0..self.buffer_count]) |*texture| {
            if (texture.*) |t| {
                t.deinit();
                texture.* = null;
            }
        }
    }

    pub fn present(self: *D3D12SwapChain) !void {
        const hr = self.swapchain.?.IDXGISwapChain_Present(
            self.sync_interval,
            self.present_flags,
        );
        if (!d3dcommon.checkHResult(hr)) return gpu.SwapChain.Error.SwapChainFailedToPresent;
        self.device.queue.fence_value += 1;
        self.device.queue.signal() catch return gpu.SwapChain.Error.SwapChainFailedToPresent;
        self.fences[self.current_index] = self.device.queue.fence_value;
    }

    pub fn resize(self: *D3D12SwapChain, size: [2]u32) !void {
        if (size[0] == self.desc.width and size[1] == self.desc.height) return;
        self.desc.width = @max(size[0], 1);
        self.desc.height = @max(size[1], 1);
        self.releaseRenderTargets();

        const resize_hr = self.swapchain.?.IDXGISwapChain_ResizeBuffers(
            self.buffer_count,
            self.desc.width,
            self.desc.height,
            .UNKNOWN,
            0,
        );
        if (!d3dcommon.checkHResult(resize_hr)) return gpu.SwapChain.Error.SwapChainFailedToResize;

        self.createRenderTargets() catch return gpu.SwapChain.Error.SwapChainFailedToResize;
    }
};

// Texture
pub fn textureCreateView(
    texture: *gpu.Texture,
    desc: *const gpu.TextureView.Descriptor,
) gpu.TextureView.Error!*gpu.TextureView {
    return @ptrCast(@alignCast(try D3D12Texture.createView(@ptrCast(@alignCast(texture)), desc)));
}

pub fn textureDestroy(texture: *gpu.Texture) void {
    std.debug.print("destroying texture...\n", .{});
    D3D12Texture.deinit(@alignCast(@ptrCast(texture)));
}

pub fn textureGetFormat(texture: *gpu.Texture) gpu.Texture.Format {
    const self: *D3D12Texture = @ptrCast(@alignCast(texture));
    return self.format;
}

pub fn textureGetDepthOrArrayLayers(texture: *gpu.Texture) u32 {
    const self: *D3D12Texture = @ptrCast(@alignCast(texture));
    return self.size.depth_or_array_layers;
}

pub fn textureGetDimension(texture: *gpu.Texture) gpu.Texture.Dimension {
    const self: *D3D12Texture = @ptrCast(@alignCast(texture));
    return self.dimension;
}

pub fn textureGetHeight(texture: *gpu.Texture) u32 {
    const self: *D3D12Texture = @ptrCast(@alignCast(texture));
    return self.size.height;
}

pub fn textureGetWidth(texture: *gpu.Texture) u32 {
    const self: *D3D12Texture = @ptrCast(@alignCast(texture));
    return self.size.width;
}

pub fn textureGetMipLevelCount(texture: *gpu.Texture) u32 {
    const self: *D3D12Texture = @ptrCast(@alignCast(texture));
    return self.mip_level_count;
}

pub fn textureGetSampleCount(texture: *gpu.Texture) u32 {
    const self: *D3D12Texture = @ptrCast(@alignCast(texture));
    return self.sample_count;
}

pub fn textureGetUsage(texture: *gpu.Texture) gpu.Texture.UsageFlags {
    const self: *D3D12Texture = @ptrCast(@alignCast(texture));
    return self.usage;
}

pub const D3D12Texture = struct {
    device: *D3D12Device,
    resource: ?D3D12Resource = null,
    usage: gpu.Texture.UsageFlags,
    dimension: gpu.Texture.Dimension,
    size: gpu.Extent3D,
    format: gpu.Texture.Format,
    mip_level_count: u32,
    sample_count: u32,

    pub fn init(
        device: *D3D12Device,
        desc: *const gpu.Texture.Descriptor,
    ) gpu.Texture.Error!*D3D12Texture {
        const heap_properties: d3d12.D3D12_HEAP_PROPERTIES = .{
            .Type = .DEFAULT,
            .CPUPageProperty = .UNKNOWN,
            .MemoryPoolPreference = .UNKNOWN,
            .CreationNodeMask = 1,
            .VisibleNodeMask = 1,
        };
        const resource_desc = d3d12.D3D12_RESOURCE_DESC{
            .Dimension = switch (desc.dimension) {
                .dimension_1d => .TEXTURE1D,
                .dimension_2d => .TEXTURE2D,
                .dimension_3d => .TEXTURE3D,
            },
            .Alignment = 0,
            .Width = desc.size.width,
            .Height = desc.size.height,
            .DepthOrArraySize = @intCast(desc.size.depth_or_array_layers),
            .MipLevels = @intCast(desc.mip_level_count),
            .Format = if (desc.view_format_count > 0)
                d3dcommon.dxgiFormatTypeless(desc.format)
            else
                d3dcommon.dxgiFormatForTexture(desc.format),
            .SampleDesc = .{
                .Count = desc.sample_count,
                .Quality = 0,
            },
            .Layout = d3d12.D3D12_TEXTURE_LAYOUT_UNKNOWN,
            .Flags = d3d12.D3D12_RESOURCE_FLAGS.initFlags(.{
                .ALLOW_DEPTH_STENCIL = if (desc.format.hasDepthOrStencil() and desc.usage.render_attachment) 1 else 0,
                .ALLOW_RENDER_TARGET = if (!desc.format.hasDepthOrStencil() and desc.usage.render_attachment) 1 else 0,
                .ALLOW_UNORDERED_ACCESS = if (desc.usage.storage) 1 else 0,
                .DENY_SHADER_RESOURCE = if (!desc.usage.texture_binding and
                    desc.usage.render_attachment and
                    desc.format.hasDepthOrStencil()) 1 else 0,
            }),
        };
        const read_state = d3d12.D3D12_RESOURCE_STATES.initFlags(.{
            .COPY_SOURCE = desc.usage.copy_src,
            .ALL_SHADER_RESOURCE = desc.usage.texture_binding or desc.usage.storage_binding,
        });
        const initial_state = read_state;

        const clear_value = d3d12.D3D12_CLEAR_VALUE{
            .Format = resource_desc.Format,
        };

        var resource: ?*d3d12.ID3D12Resource = null;
        const resource_hr = device.device.?.ID3D12Device_CreateCommittedResource(
            &heap_properties,
            .CREATE_NOT_ZEROED,
            &resource_desc,
            initial_state,
            &clear_value,
            d3d12.IID_ID3D12Resource,
            @ptrCast(&resource),
        );
        if (!d3dcommon.checkHResult(resource_hr)) return gpu.Texture.Error.TextureFailedToCreate;
        errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, &resource);

        const self = allocator.create(D3D12Texture) catch return gpu.Texture.Error.TextureFailedToCreate;
        self.* = .{
            .device = device,
            .resource = .{
                .resource = resource,
                .read_state = read_state,
            },
            .usage = desc.usage,
            .dimension = desc.dimension,
            .size = desc.size,
            .format = desc.format,
            .mip_level_count = desc.mip_level_count,
            .sample_count = desc.sample_count,
        };
        return self;
    }

    pub fn initSwapChain(device: *D3D12Device, desc: *const gpu.SwapChain.Descriptor, resource: ?*d3d12.ID3D12Resource) !*D3D12Texture {
        const self = allocator.create(D3D12Texture) catch return gpu.Texture.Error.TextureFailedToCreate;
        self.* = .{
            .device = device,
            .resource = .{
                .resource = resource,
                .read_state = d3d12.D3D12_RESOURCE_STATE_PRESENT,
            },
            .usage = desc.usage,
            .dimension = .dimension_2d,
            .size = .{
                .width = desc.width,
                .height = desc.height,
                .depth_or_array_layers = 1,
            },
            .format = desc.format,
            .mip_level_count = 1,
            .sample_count = 1,
        };
        return self;
    }

    pub fn createView(texture: *D3D12Texture, desc: *const gpu.TextureView.Descriptor) !*D3D12TextureView {
        return D3D12TextureView.init(texture, desc);
    }

    pub fn deinit(self: *D3D12Texture) void {
        var proxy: ?*d3d12.ID3D12Resource = self.resource.?.resource;
        d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, &proxy);
        allocator.destroy(self);
    }

    // internal
    pub fn calcSubresource(self: *D3D12Texture, mip_level: u32, array_slice: u32) u32 {
        return mip_level + (array_slice * self.mip_level_count);
    }
};

// TextureView
pub fn textureViewDestroy(texture_view: *gpu.TextureView) void {
    std.debug.print("destroying texture view...\n", .{});
    D3D12TextureView.deinit(@alignCast(@ptrCast(texture_view)));
}

pub const D3D12TextureView = struct {
    texture: *D3D12Texture,
    format: gpu.Texture.Format,
    dimension: gpu.TextureView.Dimension,
    base_mip_level: u32,
    mip_level_count: u32,
    base_array_layer: u32,
    array_layer_count: ?u32,
    aspect: gpu.Texture.Aspect,
    base_subresource: u32,

    pub fn init(texture: *D3D12Texture, desc: *const gpu.TextureView.Descriptor) !*D3D12TextureView {
        const self = allocator.create(D3D12TextureView) catch return gpu.TextureView.Error.TextureViewFailedToCreate;
        self.* = .{
            .texture = texture,
            .format = if (desc.format != .undefined) desc.format else texture.format,
            .dimension = if (desc.dimension != .dimension_undefined) desc.dimension else switch (texture.dimension) {
                .dimension_1d => .dimension_1d,
                .dimension_2d => .dimension_2d,
                .dimension_3d => .dimension_3d,
            },
            .base_mip_level = desc.base_mip_level,
            .mip_level_count = desc.mip_level_count orelse gpu.mip_level_count_undefined,
            .base_array_layer = desc.base_array_layer,
            .array_layer_count = desc.array_layer_count,
            .aspect = desc.aspect,
            .base_subresource = texture.calcSubresource(desc.base_mip_level, desc.base_array_layer),
        };
        return self;
    }

    pub fn deinit(self: *D3D12TextureView) void {
        allocator.destroy(self);
    }

    // internal
    pub fn width(self: *D3D12TextureView) u32 {
        return @max(1, self.texture.size.width >> @intCast(self.base_mip_level));
    }

    pub fn height(self: *D3D12TextureView) u32 {
        return @max(1, self.texture.size.height >> @intCast(self.base_mip_level));
    }

    pub fn srvDesc(self: *D3D12TextureView) d3d12.D3D12_SHADER_RESOURCE_VIEW_DESC {
        var srv_desc: d3d12.D3D12_SHADER_RESOURCE_VIEW_DESC = undefined;
        srv_desc.Format = d3dcommon.dxgiFormatForTextureView(self.format, self.aspect);
        srv_desc.ViewDimension = switch (self.dimension) {
            .dimension_undefined => unreachable,
            .dimension_1d => .TEXTURE1D,
            .dimension_2d => if (self.texture.sample_count == 1) .TEXTURE2D else .TEXTURE2DMS,
            .dimension_2d_array => if (self.texture.sample_count == 1) .TEXTURE2DARRAY else .TEXTURE2DMSARRAY,
            .dimension_cube => .TEXTURECUBE,
            .dimension_cube_array => .TEXTURECUBEARRAY,
            .dimension_3d => .TEXTURE3D,
        };
        srv_desc.Shader4ComponentMapping = d3d12.D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
        switch (srv_desc.ViewDimension) {
            .TEXTURE1D => srv_desc.Anonymous.Texture1D = .{
                .MostDetailedMip = self.base_mip_level,
                .MipLevels = self.mip_level_count,
                .ResourceMinLODClamp = 0.0,
            },
            .TEXTURE2D => srv_desc.Anonymous.Texture2D = .{
                .MostDetailedMip = self.base_mip_level,
                .MipLevels = self.mip_level_count,
                .PlaneSlice = 0, // TODO
                .ResourceMinLODClamp = 0.0,
            },
            .TEXTURE2DARRAY => srv_desc.Anonymous.Texture2DArray = .{
                .MostDetailedMip = self.base_mip_level,
                .MipLevels = self.mip_level_count,
                .FirstArraySlice = self.base_array_layer,
                .ArraySize = self.array_layer_count.?,
                .PlaneSlice = 0,
                .ResourceMinLODClamp = 0.0,
            },
            .TEXTURE2DMS => {},
            .TEXTURE2DMSARRAY => srv_desc.Anonymous.Texture2DMSArray = .{
                .FirstArraySlice = self.base_array_layer,
                .ArraySize = self.array_layer_count.?,
            },
            .TEXTURE3D => srv_desc.Anonymous.Texture3D = .{
                .MostDetailedMip = self.base_mip_level,
                .MipLevels = self.mip_level_count,
                .ResourceMinLODClamp = 0.0,
            },
            .TEXTURECUBE => srv_desc.Anonymous.TextureCube = .{
                .MostDetailedMip = self.base_mip_level,
                .MipLevels = self.mip_level_count,
                .ResourceMinLODClamp = 0.0,
            },
            .TEXTURECUBEARRAY => srv_desc.Anonymous.TextureCubeArray = .{
                .MostDetailedMip = self.base_mip_level,
                .MipLevels = self.mip_level_count,
                .First2DArrayFace = self.base_array_layer, // TODO - does this need a conversion?
                .NumCubes = self.array_layer_count.?, // TODO - does this need a conversion?
                .ResourceMinLODClamp = 0.0,
            },
            else => {},
        }
        return srv_desc;
    }

    pub fn uavDesc(self: *D3D12TextureView) d3d12.D3D12_UNORDERED_ACCESS_VIEW_DESC {
        var uav_desc: d3d12.D3D12_UNORDERED_ACCESS_VIEW_DESC = undefined;
        uav_desc.Format = d3dcommon.dxgiFormatForTextureView(self.format, self.aspect);
        uav_desc.ViewDimension = switch (self.dimension) {
            .dimension_undefined => unreachable,
            .dimension_1d => .TEXTURE1D,
            .dimension_2d => .TEXTURE2D,
            .dimension_2d_array => .TEXTURE2DARRAY,
            .dimension_3d => .TEXTURE3D,
            else => unreachable, // TODO - UAV cube maps?
        };
        switch (uav_desc.ViewDimension) {
            .TEXTURE1D => uav_desc.Anonymous.Texture1D = .{
                .MipSlice = self.base_mip_level,
            },
            .TEXTURE2D => uav_desc.Anonymous.Texture2D = .{
                .MipSlice = self.base_mip_level,
                .PlaneSlice = 0, // TODO
            },
            .TEXTURE2DARRAY => uav_desc.Anonymous.Texture2DArray = .{
                .MipSlice = self.base_mip_level,
                .FirstArraySlice = self.base_array_layer,
                .ArraySize = self.array_layer_count.?,
                .PlaneSlice = 0,
            },
            .TEXTURE3D => uav_desc.Anonymous.Texture3D = .{
                .MipSlice = self.base_mip_level,
                .FirstWSlice = self.base_array_layer, // TODO - ??
                .WSize = self.array_layer_count.?, // TODO - ??
            },
            else => {},
        }
        return uav_desc;
    }
};
