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
    .bindGroupDestroy = bindGroupDestroy,
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
    .deviceCreateBindGroup = deviceCreateBindGroup,
    .deviceCreateBindGroupLayout = deviceCreateBindGroupLayout,
    .deviceCreatePipelineLayout = deviceCreatePipelineLayout,
    .deviceCreateBuffer = deviceCreateBuffer,
    .deviceCreateCommandEncoder = deviceCreateCommandEncoder,
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
    .pipelineLayoutDestroy = pipelineLayoutDestroy,
    // QuerySet
    // Queue
    .queueSubmit = queueSubmit,
    // RenderBundle
    // RenderBundleEncoder
    // RenderPassEncoder
    .renderPassEncoderDraw = renderPassEncoderDraw,
    .renderPassEncoderDrawIndexed = renderPassEncoderDrawIndexed,
    .renderPassEncoderDrawIndexedIndirect = renderPassEncoderDrawIndexedIndirect,
    .renderPassEncoderDrawIndirect = renderPassEncoderDrawIndirect,
    .renderPassEncoderEnd = renderPassEncoderEnd,
    .renderPassEncoderExecuteBundles = renderPassEncoderExecuteBundles,
    .renderPassEncoderInsertDebugMarker = renderPassEncoderInsertDebugMarker,
    .renderPassEncoderPopDebugGroup = renderPassEncoderPopDebugGroup,
    .renderPassEncoderPushDebugGroup = renderPassEncoderPushDebugGroup,
    .renderPassEncoderSetBindGroup = renderPassEncoderSetBindGroup,
    .renderPassEncoderSetBlendConstant = renderPassEncoderSetBlendConstant,
    .renderPassEncoderSetIndexBuffer = renderPassEncoderSetIndexBuffer,
    .renderPassEncoderSetPipeline = renderPassEncoderSetPipeline,
    .renderPassEncoderSetScissorRect = renderPassEncoderSetScissorRect,
    .renderPassEncoderSetStencilReference = renderPassEncoderSetStencilReference,
    .renderPassEncoderSetVertexBuffer = renderPassEncoderSetVertexBuffer,
    .renderPassEncoderSetViewport = renderPassEncoderSetViewport,
    .renderPassEncoderWriteTimestamp = renderPassEncoderWriteTimestamp,
    .renderPassEncoderDestroy = renderPassEncoderDestroy,
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
    // Texture
    .textureCreateView = textureCreateView,
    .textureDestroy = textureDestroy,
    .textureGetFormat = textureGetFormat,
    .textureGetDepthOrArrayLayers = textureGetDepthOrArrayLayers,
    .textureGetDimension = textureGetDimension,
    .textureGetHeight = textureGetHeight,
    .textureGetWidth = textureGetWidth,
    .textureGetMipLevelCount = textureGetMipLevelCount,
    .textureGetSampleCount = textureGetSampleCount,
    .textureGetUsage = textureGetUsage,
    // TextureView
    .textureViewDestroy = textureViewDestroy,
};

export fn getProcs() *const gpu.procs.Procs {
    return &procs;
}

// BindGroup
pub fn bindGroupDestroy(bind_group: *gpu.BindGroup) void {
    std.debug.print("destroying bind group...\n", .{});
    D3D12BindGroup.deinit(@alignCast(@ptrCast(bind_group)));
}

pub const D3D12BindGroup = struct {
    const ResourceAccess = struct {
        resource: *D3D12Resource,
        uav: bool,
    };
    const DynamicResource = struct {
        address: u64, // d3d12.D3D12_GPU_VIRTUAL_ADDRESS
        parameter_type: d3d12.D3D12_ROOT_PARAMETER_TYPE,
    };

    device: *D3D12Device,
    general_allocation: ?D3D12DescriptorHeap.Allocation,
    general_table: ?d3d12.D3D12_GPU_DESCRIPTOR_HANDLE,
    sampler_allocation: ?D3D12DescriptorHeap.Allocation,
    sampler_table: ?d3d12.D3D12_GPU_DESCRIPTOR_HANDLE,
    dynamic_resources: []DynamicResource,
    buffers: std.ArrayListUnmanaged(*D3D12Buffer),
    textures: std.ArrayListUnmanaged(*D3D12Texture),
    accesses: std.ArrayListUnmanaged(ResourceAccess),

    pub fn init(device: *D3D12Device, desc: *const gpu.BindGroup.Descriptor) !*D3D12BindGroup {
        const layout: *D3D12BindGroupLayout = @ptrCast(@alignCast(desc.layout));

        // General Descriptor Table
        var general_allocation: ?D3D12DescriptorHeap.Allocation = null;
        var general_table: ?d3d12.D3D12_GPU_DESCRIPTOR_HANDLE = null;

        if (layout.general_table_size > 0) {
            const allocation = device.general_heap.alloc() catch return gpu.BindGroup.Error.BindGroupFailedToCreate;
            general_allocation = allocation;
            general_table = device.general_heap.gpuDescriptor(allocation);

            for (desc.entries orelse &.{}) |entry| {
                const layout_entry = layout.getEntry(entry.binding) orelse
                    return gpu.BindGroup.Error.BindGroupUnknownBinding;
                if (layout_entry.sampler.type != .undefined)
                    continue;

                if (layout_entry.table_index) |table_index| {
                    const dest_descriptor = device.general_heap.cpuDescriptor(allocation + table_index);

                    if (layout_entry.buffer.type != .undefined) {
                        const buffer: *D3D12Buffer = @ptrCast(@alignCast(entry.buffer.?));
                        const d3d_resource = buffer.buffer.resource.?;

                        const buffer_location = d3d_resource.ID3D12Resource_GetGPUVirtualAddress() + entry.offset;

                        switch (layout_entry.buffer.type) {
                            .undefined => unreachable,
                            .uniform => {
                                const cbv_desc: d3d12.D3D12_CONSTANT_BUFFER_VIEW_DESC = .{
                                    .BufferLocation = buffer_location,
                                    .SizeInBytes = @intCast(gpu.util.alignUp(entry.size, gpu.Limits.min_uniform_buffer_offset_alignment)),
                                };

                                device.device.?.ID3D12Device_CreateConstantBufferView(
                                    &cbv_desc,
                                    dest_descriptor,
                                );
                            },
                            .storage => {
                                // TODO - switch to RWByteAddressBuffer after using DXC
                                const stride = entry.element_size;
                                const uav_desc: d3d12.D3D12_UNORDERED_ACCESS_VIEW_DESC = .{
                                    .Format = .UNKNOWN,
                                    .ViewDimension = d3d12.D3D12_UAV_DIMENSION_BUFFER,
                                    .Anonymous = .{
                                        .Buffer = .{
                                            .FirstElement = @intCast(entry.offset / stride),
                                            .NumElements = @intCast(entry.size / stride),
                                            .StructureByteStride = stride,
                                            .CounterOffsetInBytes = 0,
                                            .Flags = d3d12.D3D12_BUFFER_UAV_FLAG_NONE,
                                        },
                                    },
                                };

                                device.device.?.ID3D12Device_CreateUnorderedAccessView(
                                    d3d_resource,
                                    null,
                                    &uav_desc,
                                    dest_descriptor,
                                );
                            },
                            .read_only_storage => {
                                // TODO - switch to ByteAddressBuffer after using DXC
                                const stride = entry.element_size;
                                const srv_desc: d3d12.D3D12_SHADER_RESOURCE_VIEW_DESC = .{
                                    .Format = dxgi.common.DXGI_FORMAT_UNKNOWN,
                                    .ViewDimension = d3d12.D3D12_SRV_DIMENSION_BUFFER,
                                    .Shader4ComponentMapping = d3d12.D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING,
                                    .Anonymous = .{
                                        .Buffer = .{
                                            .FirstElement = @intCast(entry.offset / stride),
                                            .NumElements = @intCast(entry.size / stride),
                                            .StructureByteStride = stride,
                                            .Flags = d3d12.D3D12_BUFFER_SRV_FLAG_NONE,
                                        },
                                    },
                                };

                                device.device.?.ID3D12Device_CreateShaderResourceView(
                                    d3d_resource,
                                    &srv_desc,
                                    dest_descriptor,
                                );
                            },
                        }
                    } else if (layout_entry.texture.sample_type != .undefined) {
                        const texture_view: *D3D12TextureView = @ptrCast(@alignCast(entry.texture_view.?));
                        const d3d_resource = texture_view.texture.resource.?.resource;

                        device.device.?.ID3D12Device_CreateShaderResourceView(
                            d3d_resource,
                            &texture_view.srvDesc(),
                            dest_descriptor,
                        );
                    } else if (layout_entry.storage_texture.format != .undefined) {
                        const texture_view: *D3D12TextureView = @ptrCast(@alignCast(entry.texture_view.?));
                        const d3d_resource = texture_view.texture.resource.?.resource;

                        device.device.?.ID3D12Device_CreateUnorderedAccessView(
                            d3d_resource,
                            null,
                            &texture_view.uavDesc(),
                            dest_descriptor,
                        );
                    }
                }
            }
        }

        // Sampler Descriptor Table
        var sampler_allocation: ?D3D12DescriptorHeap.Allocation = null;
        var sampler_table: ?d3d12.D3D12_GPU_DESCRIPTOR_HANDLE = null;

        if (layout.sampler_table_size > 0) {
            const allocation = device.sampler_heap.alloc() catch return gpu.BindGroup.Error.BindGroupFailedToCreate;
            sampler_allocation = allocation;
            sampler_table = device.sampler_heap.gpuDescriptor(allocation);

            for (desc.entries orelse &.{}) |entry| {
                const layout_entry = layout.getEntry(entry.binding) orelse
                    return gpu.BindGroup.Error.BindGroupUnknownBinding;
                if (layout_entry.sampler.type == .undefined)
                    continue;

                if (layout_entry.table_index) |table_index| {
                    const dest_descriptor = device.sampler_heap.cpuDescriptor(allocation + table_index);

                    const sampler: *D3D12Sampler = @ptrCast(@alignCast(entry.sampler.?));

                    device.device.?.ID3D12Device_CreateSampler(
                        &sampler.desc,
                        dest_descriptor,
                    );
                }
            }
        }

        // Resource tracking and dynamic resources
        var dynamic_resources = allocator.alloc(DynamicResource, layout.dynamic_entries.items.len) catch
            return gpu.BindGroup.Error.BindGroupFailedToCreate;
        errdefer allocator.free(dynamic_resources);

        var buffers = std.ArrayListUnmanaged(*D3D12Buffer){};
        errdefer buffers.deinit(allocator);

        var textures = std.ArrayListUnmanaged(*D3D12Texture){};
        errdefer textures.deinit(allocator);

        var accesses = std.ArrayListUnmanaged(ResourceAccess){};
        errdefer accesses.deinit(allocator);

        for (desc.entries orelse &.{}) |entry| {
            const layout_entry = layout.getEntry(entry.binding) orelse
                return gpu.BindGroup.Error.BindGroupUnknownBinding;

            if (layout_entry.buffer.type != .undefined) {
                const buffer: *D3D12Buffer = @ptrCast(@alignCast(entry.buffer.?));
                const d3d_resource = buffer.buffer.resource.?;

                buffers.append(allocator, buffer) catch
                    return gpu.BindGroup.Error.BindGroupFailedToCreate;

                const buffer_location = d3d_resource.ID3D12Resource_GetGPUVirtualAddress() + entry.offset;
                if (layout_entry.dynamic_index) |dynamic_index| {
                    const layout_dynamic_entry = layout.dynamic_entries.items[dynamic_index];
                    dynamic_resources[dynamic_index] = .{
                        .address = buffer_location,
                        .parameter_type = layout_dynamic_entry.parameter_type,
                    };
                }

                accesses.append(allocator, .{
                    .resource = &buffer.buffer,
                    .uav = layout_entry.buffer.type == .storage,
                }) catch
                    return gpu.BindGroup.Error.BindGroupFailedToCreate;
            } else if (layout_entry.sampler.type != .undefined) {} else if (layout_entry.texture.sample_type != .undefined) {
                const texture_view: *D3D12TextureView = @ptrCast(@alignCast(entry.texture_view.?));
                const texture = texture_view.texture;

                textures.append(allocator, texture) catch
                    return gpu.BindGroup.Error.BindGroupFailedToCreate;

                accesses.append(allocator, .{ .resource = &texture.resource.?, .uav = false }) catch
                    return gpu.BindGroup.Error.BindGroupFailedToCreate;
            } else if (layout_entry.storage_texture.format != .undefined) {
                const texture_view: *D3D12TextureView = @ptrCast(@alignCast(entry.texture_view.?));
                const texture = texture_view.texture;

                textures.append(allocator, texture) catch
                    return gpu.BindGroup.Error.BindGroupFailedToCreate;

                accesses.append(allocator, .{ .resource = &texture.resource.?, .uav = true }) catch
                    return gpu.BindGroup.Error.BindGroupFailedToCreate;
            }
        }

        const group = allocator.create(D3D12BindGroup) catch
            return gpu.BindGroup.Error.BindGroupFailedToCreate;
        group.* = .{
            .device = device,
            .general_allocation = general_allocation,
            .general_table = general_table,
            .sampler_allocation = sampler_allocation,
            .sampler_table = sampler_table,
            .dynamic_resources = dynamic_resources,
            .buffers = buffers,
            .textures = textures,
            .accesses = accesses,
        };
        return group;
    }

    pub fn deinit(group: *D3D12BindGroup) void {
        if (group.general_allocation) |allocation|
            group.device.general_heap.free(allocation);
        if (group.sampler_allocation) |allocation|
            group.device.sampler_heap.free(allocation);

        group.buffers.deinit(allocator);
        group.textures.deinit(allocator);
        group.accesses.deinit(allocator);
        allocator.free(group.dynamic_resources);
        allocator.destroy(group);
    }
};

// BindGroupLayout
pub fn bindGroupLayoutDestroy(bind_group_layout: *gpu.BindGroupLayout) void {
    std.debug.print("destroying bind group layout...\n", .{});
    D3D12BindGroupLayout.deinit(@alignCast(@ptrCast(bind_group_layout)));
}

pub const D3D12BindGroupLayout = struct {
    const Entry = struct {
        binding: u32,
        visibility: gpu.ShaderStageFlags,
        buffer: gpu.Buffer.BindingLayout = .{},
        sampler: gpu.Sampler.BindingLayout = .{},
        texture: gpu.Texture.BindingLayout = .{},
        storage_texture: gpu.StorageTextureBindingLayout = .{},
        range_type: d3d12.D3D12_DESCRIPTOR_RANGE_TYPE,
        table_index: ?u32,
        dynamic_index: ?u32,
    };

    const DynamicEntry = struct {
        parameter_type: d3d12.D3D12_ROOT_PARAMETER_TYPE,
    };

    entries: std.ArrayListUnmanaged(Entry),
    dynamic_entries: std.ArrayListUnmanaged(DynamicEntry),
    general_table_size: u32,
    sampler_table_size: u32,

    pub fn init(device: *D3D12Device, desc: *const gpu.BindGroupLayout.Descriptor) !*D3D12BindGroupLayout {
        _ = device;

        var entries = std.ArrayListUnmanaged(Entry){};
        errdefer entries.deinit(allocator);

        var dynamic_entries = std.ArrayListUnmanaged(DynamicEntry){};
        errdefer dynamic_entries.deinit(allocator);

        var general_table_size: u32 = 0;
        var sampler_table_size: u32 = 0;
        for (desc.entries orelse &.{}) |entry| {
            var table_index: ?u32 = null;
            var dynamic_index: ?u32 = null;
            if (entry.buffer.has_dynamic_offset == true) {
                dynamic_index = @intCast(dynamic_entries.items.len);
                dynamic_entries.append(allocator, .{
                    .parameter_type = switch (entry.buffer.type) {
                        .undefined => unreachable,
                        .uniform => d3d12.D3D12_ROOT_PARAMETER_TYPE_CBV,
                        .storage => d3d12.D3D12_ROOT_PARAMETER_TYPE_UAV,
                        .read_only_storage => d3d12.D3D12_ROOT_PARAMETER_TYPE_SRV,
                    },
                }) catch return gpu.BindGroupLayout.Error.BindGroupLayoutFailedToCreate;
            } else if (entry.sampler.type != .undefined) {
                table_index = sampler_table_size;
                sampler_table_size += 1;
            } else {
                table_index = general_table_size;
                general_table_size += 1;
            }

            entries.append(allocator, .{
                .binding = entry.binding,
                .visibility = entry.visibility,
                .buffer = entry.buffer,
                .sampler = entry.sampler,
                .texture = entry.texture,
                .storage_texture = entry.storage_texture,
                .range_type = blk: {
                    if (entry.buffer.type != .undefined) {
                        break :blk switch (entry.buffer.type) {
                            .undefined => unreachable,
                            .uniform => d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_CBV,
                            .storage => d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_UAV,
                            .read_only_storage => d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_SRV,
                        };
                    } else if (entry.sampler.type != .undefined) {
                        break :blk d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_SAMPLER;
                    } else if (entry.texture.sample_type != .undefined) {
                        break :blk d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
                    } else {
                        // storage_texture
                        break :blk d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_UAV;
                    }

                    unreachable;
                },
                .table_index = table_index,
                .dynamic_index = dynamic_index,
            }) catch return gpu.BindGroupLayout.Error.BindGroupLayoutFailedToCreate;
        }

        const layout = allocator.create(D3D12BindGroupLayout) catch
            return gpu.BindGroupLayout.Error.BindGroupLayoutFailedToCreate;
        layout.* = .{
            .entries = entries,
            .dynamic_entries = dynamic_entries,
            .general_table_size = general_table_size,
            .sampler_table_size = sampler_table_size,
        };
        return layout;
    }

    pub fn deinit(layout: *D3D12BindGroupLayout) void {
        layout.entries.deinit(allocator);
        layout.dynamic_entries.deinit(allocator);
        allocator.destroy(layout);
    }

    pub fn getEntry(self: *D3D12BindGroupLayout, binding: u32) ?*const Entry {
        for (self.entries.items) |*entry| {
            if (entry.binding == binding)
                return entry;
        }

        return null;
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

    // pub fn beginComputePass(self: *D3D12CommandEncoder, desc: *const gpu.ComputePassDescriptor) gpu.Compute

    pub fn beginRenderPass(self: *D3D12CommandEncoder, desc: *const gpu.RenderPass.Descriptor) !*D3D12RenderPassEncoder {
        try self.barrier_enforcer.endPass();
        return D3D12RenderPassEncoder.init(self, desc);
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
                .pResource = source_buffer.buffer.resource,
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
                .Anonymous = .{
                    .SubresourceIndex = destination_subresource_index,
                },
            },
            destination_origin.x,
            destination_origin.y,
            destination_origin.z,
            &.{
                .pResource = source_texture.resource.d3d_resource,
                .Type = .SUBRESOURCE_INDEX,
                .Anonymous = .{
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

    pub fn writeBuffer(
        self: *D3D12CommandEncoder,
        buffer: *D3D12Buffer,
        offset: u64,
        data: []const u8,
    ) !void {
        const command_list = self.command_buffer.command_list.?;

        const stream = try self.command_buffer.upload(data.len);
        @memcpy(stream.map[0..data.len], data);

        try self.barrier_enforcer.transition(&buffer.buffer, .COPY_DEST);
        self.barrier_enforcer.flush(command_list);

        command_list.ID3D12GraphicsCommandList_CopyBufferRegion(
            buffer.buffer.buffer,
            offset,
            stream.d3d_resource,
            stream.offset,
            data.len,
        );
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
                .Anonymous = .{
                    .SubresourceIndex = destination_subresource_index,
                },
            },
            destination_origin.x,
            destination_origin.y,
            destination_origin.z,
            &.{
                .pResource = stream.d3d_resource,
                .Type = .PLACED_FOOTPRINT,
                .Anonymous = .{
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
pub fn deviceCreateBindGroup(
    device: *gpu.Device,
    desc: *const gpu.BindGroup.Descriptor,
) gpu.BindGroup.Error!*gpu.BindGroup {
    std.debug.print("creating bind group...\n", .{});
    return @ptrCast(try D3D12BindGroup.init(@ptrCast(@alignCast(device)), desc));
}

pub fn deviceCreateBindGroupLayout(
    device: *gpu.Device,
    desc: *const gpu.BindGroupLayout.Descriptor,
) gpu.BindGroupLayout.Error!*gpu.BindGroupLayout {
    std.debug.print("creating bind group layout...\n", .{});
    return @ptrCast(try D3D12BindGroupLayout.init(@ptrCast(@alignCast(device)), desc));
}

pub fn deviceCreatePipelineLayout(
    device: *gpu.Device,
    desc: *const gpu.PipelineLayout.Descriptor,
) gpu.PipelineLayout.Error!*gpu.PipelineLayout {
    std.debug.print("creating pipeline layout...\n", .{});
    return @ptrCast(try D3D12PipelineLayout.init(@ptrCast(@alignCast(device)), desc));
}

pub fn deviceCreateBuffer(
    device: *gpu.Device,
    desc: *const gpu.Buffer.Descriptor,
) gpu.Buffer.Error!*gpu.Buffer {
    std.debug.print("creating buffer...\n", .{});
    return @ptrCast(try D3D12Buffer.init(@ptrCast(@alignCast(device)), desc));
}

pub fn deviceCreateCommandEncoder(
    device: *gpu.Device,
    desc: *const gpu.CommandEncoder.Descriptor,
) gpu.CommandEncoder.Error!*gpu.CommandEncoder {
    std.debug.print("creating command encoder...\n", .{});
    return @ptrCast(try D3D12CommandEncoder.init(@ptrCast(@alignCast(device)), desc));
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
            try heap.free_blocks.append(allocator, index);
        }

        return heap.free_blocks.pop();
    }

    pub fn free(heap: *D3D12DescriptorHeap, allocation: Allocation) void {
        heap.free_blocks.append(allocator, allocation) catch {
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
pub fn pipelineLayoutDestroy(pipeline_layout: *gpu.PipelineLayout) void {
    std.debug.print("destroying pipeline_layout...\n", .{});
    D3D12PipelineLayout.deinit(@alignCast(@ptrCast(pipeline_layout)));
}

pub const D3D12PipelineLayout = struct {
    pub const Function = struct {
        stage: gpu.ShaderStageFlags,
        shader_module: *gpu.ShaderModule,
        entry_point: [*:0]const u8,
    };

    root_signature: *d3d12.ID3D12RootSignature,
    group_layouts: []*D3D12BindGroupLayout,
    group_parameter_indices: std.BoundedArray(u32, gpu.Limits.max_bind_groups),

    pub fn init(device: *D3D12Device, desc: *const gpu.PipelineLayout.Descriptor) !*D3D12PipelineLayout {
        var hr: win32.foundation.HRESULT = undefined;

        var scratch = common.ScratchSpace(8192){};
        const temp_allocator = scratch.init().allocator();

        // Per Bind Group:
        // - up to 1 descriptor table for CBV/SRV/UAV
        // - up to 1 descriptor table for Sampler
        // - 1 root descriptor per dynamic resource
        // Root signature 1.1 hints not supported yet

        var group_layouts = allocator.alloc(*D3D12BindGroupLayout, (desc.bind_group_layouts orelse &.{}).len) catch
            return gpu.PipelineLayout.Error.PipelineLayoutFailedToCreate;
        errdefer allocator.free(group_layouts);

        var group_parameter_indices =
            std.BoundedArray(u32, gpu.Limits.max_bind_groups){};

        var parameter_count: u32 = 0;
        var range_count: u32 = 0;
        for (desc.bind_group_layouts orelse &.{}, 0..) |bgl, i| {
            const layout: *D3D12BindGroupLayout = @ptrCast(@alignCast(bgl));
            group_layouts[i] = layout;
            group_parameter_indices.appendAssumeCapacity(parameter_count);

            var general_entry_count: u32 = 0;
            var sampler_entry_count: u32 = 0;
            for (layout.entries.items) |entry| {
                if (entry.dynamic_index) |_| {
                    parameter_count += 1;
                } else if (entry.sampler.type != .undefined) {
                    sampler_entry_count += 1;
                    range_count += 1;
                } else {
                    general_entry_count += 1;
                    range_count += 1;
                }
            }

            if (general_entry_count > 0)
                parameter_count += 1;
            if (sampler_entry_count > 0)
                parameter_count += 1;
        }

        var parameters = std.ArrayListUnmanaged(
            d3d12.D3D12_ROOT_PARAMETER,
        ).initCapacity(
            temp_allocator,
            parameter_count,
        ) catch return gpu.PipelineLayout.Error.PipelineLayoutFailedToCreate;
        defer parameters.deinit(temp_allocator);

        var ranges = std.ArrayListUnmanaged(
            d3d12.D3D12_DESCRIPTOR_RANGE,
        ).initCapacity(
            temp_allocator,
            range_count,
        ) catch return gpu.PipelineLayout.Error.PipelineLayoutFailedToCreate;
        defer ranges.deinit(temp_allocator);

        for (desc.bind_group_layouts orelse &.{}, 0..) |bgl, group_index| {
            const layout: *D3D12BindGroupLayout = @ptrCast(@alignCast(bgl));

            // General Table
            {
                const entry_range_base = ranges.items.len;
                for (layout.entries.items) |entry| {
                    if (entry.dynamic_index == null and entry.sampler.type == .undefined) {
                        ranges.appendAssumeCapacity(.{
                            .RangeType = entry.range_type,
                            .NumDescriptors = 1,
                            .BaseShaderRegister = entry.binding,
                            .RegisterSpace = @intCast(group_index),
                            .OffsetInDescriptorsFromTableStart = d3d12.D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND,
                        });
                    }
                }
                const entry_range_count = ranges.items.len - entry_range_base;
                if (entry_range_count > 0) {
                    parameters.appendAssumeCapacity(.{
                        .ParameterType = d3d12.D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
                        .Anonymous = .{
                            .DescriptorTable = .{
                                .NumDescriptorRanges = @intCast(entry_range_count),
                                .pDescriptorRanges = @ptrCast(&ranges.items[entry_range_base]),
                            },
                        },
                        .ShaderVisibility = d3d12.D3D12_SHADER_VISIBILITY_ALL,
                    });
                }
            }

            // Sampler Table
            {
                const entry_range_base = ranges.items.len;
                for (layout.entries.items) |entry| {
                    if (entry.dynamic_index == null and entry.sampler.type != .undefined) {
                        ranges.appendAssumeCapacity(.{
                            .RangeType = entry.range_type,
                            .NumDescriptors = 1,
                            .BaseShaderRegister = entry.binding,
                            .RegisterSpace = @intCast(group_index),
                            .OffsetInDescriptorsFromTableStart = d3d12.D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND,
                        });
                    }
                }
                const entry_range_count = ranges.items.len - entry_range_base;
                if (entry_range_count > 0) {
                    parameters.appendAssumeCapacity(.{
                        .ParameterType = d3d12.D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE,
                        .Anonymous = .{
                            .DescriptorTable = .{
                                .NumDescriptorRanges = @intCast(entry_range_count),
                                .pDescriptorRanges = @ptrCast(&ranges.items[entry_range_base]),
                            },
                        },
                        .ShaderVisibility = d3d12.D3D12_SHADER_VISIBILITY_ALL,
                    });
                }
            }

            // Dynamic Resources
            for (layout.entries.items) |entry| {
                if (entry.dynamic_index) |dynamic_index| {
                    const layout_dynamic_entry = layout.dynamic_entries.items[dynamic_index];
                    parameters.appendAssumeCapacity(.{
                        .ParameterType = layout_dynamic_entry.parameter_type,
                        .Anonymous = .{
                            .Descriptor = .{
                                .ShaderRegister = entry.binding,
                                .RegisterSpace = @intCast(group_index),
                            },
                        },
                        .ShaderVisibility = d3d12.D3D12_SHADER_VISIBILITY_ALL,
                    });
                }
            }
        }

        var root_signature_blob: ?*d3d.ID3DBlob = null;
        var opt_errors: ?*d3d.ID3DBlob = null;
        hr = d3d12.D3D12SerializeRootSignature(
            &d3d12.D3D12_ROOT_SIGNATURE_DESC{
                .NumParameters = @intCast(parameters.items.len),
                .pParameters = parameters.items.ptr,
                .NumStaticSamplers = 0,
                .pStaticSamplers = undefined,
                .Flags = d3d12.D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT, // TODO - would like a flag for this
            },
            d3d12.D3D_ROOT_SIGNATURE_VERSION_1,
            @ptrCast(&root_signature_blob),
            @ptrCast(&opt_errors),
        );
        if (opt_errors) |errors| {
            const message: [*:0]const u8 = @ptrCast(errors.ID3DBlob_GetBufferPointer().?);
            std.debug.print("{s}\n", .{message});
            d3dcommon.releaseIUnknown(d3d.ID3DBlob, &opt_errors);
        }
        if (winapi.zig.FAILED(hr)) {
            return gpu.PipelineLayout.Error.PipelineLayoutSerializeRootSignatureFailed;
        }
        defer d3dcommon.releaseIUnknown(d3d.ID3DBlob, &root_signature_blob);

        var root_signature: ?*d3d12.ID3D12RootSignature = null;
        hr = device.device.?.ID3D12Device_CreateRootSignature(
            0,
            @ptrCast(root_signature_blob.?.ID3DBlob_GetBufferPointer()),
            root_signature_blob.?.ID3DBlob_GetBufferSize(),
            d3d12.IID_ID3D12RootSignature,
            @ptrCast(&root_signature),
        );
        errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12RootSignature, &root_signature);

        // Result
        const layout = allocator.create(D3D12PipelineLayout) catch
            return gpu.PipelineLayout.Error.PipelineLayoutFailedToCreate;
        layout.* = .{
            .root_signature = root_signature.?,
            .group_layouts = group_layouts,
            .group_parameter_indices = group_parameter_indices,
        };
        return layout;
    }

    pub fn deinit(layout: *D3D12PipelineLayout) void {
        var root_signature: ?*d3d12.ID3D12RootSignature = layout.root_signature;

        d3dcommon.releaseIUnknown(d3d12.ID3D12RootSignature, &root_signature);
        allocator.free(layout.group_layouts);
        allocator.destroy(layout);
    }
};

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
pub fn renderPassEncoderDraw(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
) void {
    std.debug.print("drawing...\n", .{});
    D3D12RenderPassEncoder.draw(
        @ptrCast(@alignCast(render_pass_encoder)),
        vertex_count,
        instance_count,
        first_vertex,
        first_instance,
    );
}

pub fn renderPassEncoderDrawIndexed(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
) void {
    std.debug.print("drawing indexed...\n", .{});
    D3D12RenderPassEncoder.drawIndexed(
        @ptrCast(@alignCast(render_pass_encoder)),
        index_count,
        instance_count,
        first_index,
        base_vertex,
        first_instance,
    );
}

pub fn renderPassEncoderDrawIndexedIndirect(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    indirect_buffer: *gpu.Buffer,
    indirect_offset: u64,
) void {
    _ = render_pass_encoder;
    _ = indirect_buffer;
    _ = indirect_offset;
    std.debug.print("drawing indexed indirect...\n", .{});
    // TODO: DrawIndexedIndirect
    // D3D12RenderPassEncoder.drawIndexedIndirect(
    //     @ptrCast(@alignCast(render_pass_encoder)),
    //     @ptrCast(@alignCast(indirect_buffer)),
    //     indirect_offset,
    // );
}

pub fn renderPassEncoderDrawIndirect(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    indirect_buffer: *gpu.Buffer,
    indirect_offset: u64,
) void {
    _ = render_pass_encoder;
    _ = indirect_buffer;
    _ = indirect_offset;
    std.debug.print("drawing indirect...\n", .{});
    // TODO: DrawIndirect
    // D3D12RenderPassEncoder.drawIndirect(
    //     @ptrCast(@alignCast(render_pass_encoder)),
    //     @ptrCast(@alignCast(indirect_buffer)),
    //     indirect_offset,
    // );
}

pub fn renderPassEncoderEnd(render_pass_encoder: *gpu.RenderPass.Encoder) gpu.RenderPass.Encoder.Error!void {
    std.debug.print("ending render_pass...\n", .{});
    try D3D12RenderPassEncoder.end(@ptrCast(@alignCast(render_pass_encoder)));
}

pub fn renderPassEncoderExecuteBundles(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    bundles: []const *gpu.RenderBundle,
) void {
    _ = render_pass_encoder;
    _ = bundles;
    std.debug.print("executing bundles...\n", .{});
    // TODO: ExecuteBundles
}

pub fn renderPassEncoderInsertDebugMarker(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    label: []const u8,
) void {
    _ = render_pass_encoder;
    std.debug.print("inserting debug marker...: {s}\n", .{label});
}

pub fn renderPassEncoderPopDebugGroup(render_pass_encoder: *gpu.RenderPass.Encoder) void {
    _ = render_pass_encoder;
    std.debug.print("popping debug group...\n", .{});
}

pub fn renderPassEncoderPushDebugGroup(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    label: []const u8,
) void {
    _ = render_pass_encoder;
    std.debug.print("pushing debug group...: {s}\n", .{label});
}

pub fn renderPassEncoderSetBindGroup(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    index: u32,
    bind_group: *gpu.BindGroup,
    dynamic_offsets: ?[]const u32,
) void {
    std.debug.print("setting bind_group...\n", .{});
    D3D12RenderPassEncoder.setBindGroup(
        @ptrCast(@alignCast(render_pass_encoder)),
        index,
        @ptrCast(@alignCast(bind_group)),
        dynamic_offsets,
    );
}

pub fn renderPassEncoderSetBlendConstant(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    color: [4]f32,
) void {
    _ = render_pass_encoder;
    _ = color;
    std.debug.print("setting blend constant...\n", .{});
    // TODO: SetBlendConstant
    // D3D12RenderPassEncoder.setBlendConstant(
    //     @ptrCast(@alignCast(render_pass_encoder)),
    //     color,
    // );
}

pub fn renderPassEncoderSetIndexBuffer(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    buffer: *gpu.Buffer,
    format: gpu.IndexFormat,
    offset: u64,
    size: u64,
) gpu.RenderPass.Encoder.Error!void {
    std.debug.print("setting index buffer...\n", .{});
    try D3D12RenderPassEncoder.setIndexBuffer(
        @ptrCast(@alignCast(render_pass_encoder)),
        @ptrCast(@alignCast(buffer)),
        format,
        offset,
        size,
    );
}

pub fn renderPassEncoderSetPipeline(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    pipeline: *gpu.RenderPipeline,
) gpu.RenderPass.Encoder.Error!void {
    std.debug.print("setting pipeline...\n", .{});
    try D3D12RenderPassEncoder.setPipeline(
        @ptrCast(@alignCast(render_pass_encoder)),
        @ptrCast(@alignCast(pipeline)),
    );
}

pub fn renderPassEncoderSetScissorRect(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
) gpu.RenderPass.Encoder.Error!void {
    std.debug.print("setting scissor rect...\n", .{});
    try D3D12RenderPassEncoder.setScissorRect(
        @ptrCast(@alignCast(render_pass_encoder)),
        x,
        y,
        width,
        height,
    );
}

pub fn renderPassEncoderSetStencilReference(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    reference: u32,
) void {
    _ = render_pass_encoder;
    _ = reference;
    std.debug.print("setting stencil reference...\n", .{});
    // TODO: SetStencilReference
    // D3D12RenderPassEncoder.setStencilReference(
    //     @ptrCast(@alignCast(render_pass_encoder)),
    //     reference,
    // );
}

pub fn renderPassEncoderSetVertexBuffer(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    slot: u32,
    buffer: *gpu.Buffer,
    offset: u64,
    size: u64,
) gpu.RenderPass.Encoder.Error!void {
    std.debug.print("setting vertex buffer...\n", .{});
    try D3D12RenderPassEncoder.setVertexBuffer(
        @ptrCast(@alignCast(render_pass_encoder)),
        slot,
        @ptrCast(@alignCast(buffer)),
        offset,
        size,
    );
}

pub fn renderPassEncoderSetViewport(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
) gpu.RenderPass.Encoder.Error!void {
    std.debug.print("setting viewport...\n", .{});
    try D3D12RenderPassEncoder.setViewport(
        @ptrCast(@alignCast(render_pass_encoder)),
        x,
        y,
        width,
        height,
        min_depth,
        max_depth,
    );
}

pub fn renderPassEncoderWriteTimestamp(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    query_set: *gpu.QuerySet,
    query_index: u32,
) void {
    _ = render_pass_encoder;
    _ = query_set;
    _ = query_index;
    std.debug.print("writing timestamp...\n", .{});
    // TODO: WriteTimestamp
}

pub fn renderPassEncoderDestroy(render_pass_encoder: *gpu.RenderPass.Encoder) void {
    std.debug.print("destroying render_pass_encoder...\n", .{});
    D3D12RenderPassEncoder.deinit(@alignCast(@ptrCast(render_pass_encoder)));
}

pub const D3D12RenderPassEncoder = struct {
    command_list: ?*d3d12.ID3D12GraphicsCommandList = null,
    barrier_enforcer: *D3D12BarrierEnforcer,
    color_attachments: std.BoundedArray(gpu.RenderPass.ColourAttachment, gpu.Limits.max_colour_attachments) = .{},
    depth_attachment: ?gpu.RenderPass.DepthStencilAttachment,
    group_parameter_indices: []u32 = undefined,
    vertex_apply_count: u32 = 0,
    vertex_buffer_views: [gpu.Limits.max_vertex_buffers]d3d12.D3D12_VERTEX_BUFFER_VIEW,
    vertex_strides: []u32 = undefined,

    pub fn init(self: *D3D12CommandEncoder, desc: *const gpu.RenderPass.Descriptor) !*D3D12RenderPassEncoder {
        const command_list = self.command_buffer.command_list.?;

        var width: u32 = 0;
        var height: u32 = 0;
        var color_attachments: std.BoundedArray(
            gpu.RenderPass.ColourAttachment,
            gpu.Limits.max_colour_attachments,
        ) = .{};
        var rtv_handles = try self.command_buffer.allocateRtvDescriptors(desc.color_attachment_count);
        const descriptor_size = self.device.rtv_heap.descriptor_size;

        var rtv_handle = rtv_handles;
        for (desc.colour_attachments orelse &.{}) |attach| {
            if (attach.view) |view_raw| {
                const view: *D3D12TextureView = @ptrCast(@alignCast(view_raw));
                const texture = view.texture;

                try self.barrier_enforcer.transition(&texture.resource, d3d12.D3D12_RESOURCE_STATE_RENDER_TARGET);

                width = view.width();
                height = view.height();
                color_attachments.appendAssumeCapacity(attach);

                // TODO - rtvDesc()
                self.device.device.?.ID3D12Device_CreateRenderTargetView(
                    texture.resource.d3d_resource,
                    null,
                    rtv_handle,
                );
            } else {
                self.device.device.?.ID3D12Device_CreateRenderTargetView(
                    null,
                    &.{
                        .Format = d3d12.DXGI_FORMAT_R8G8B8A8_UNORM,
                        .ViewDimension = d3d12.D3D12_RTV_DIMENSION_TEXTURE2D,
                        .unnamed_0 = .{ .Texture2D = .{ .MipSlice = 0, .PlaneSlice = 0 } },
                    },
                    rtv_handle,
                );
            }
            rtv_handle.ptr += descriptor_size;
        }

        var depth_attachment: ?gpu.RenderPassDepthStencilAttachment = null;
        var dsv_handle: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE = .{ .ptr = 0 };

        if (desc.depth_stencil_attachment) |attach| {
            const view: *D3D12TextureView = @ptrCast(@alignCast(attach.view));
            const texture = view.texture;

            try self.barrier_enforcer.transition(&texture.resource, d3d12.D3D12_RESOURCE_STATE_DEPTH_WRITE);

            width = view.width();
            height = view.height();
            depth_attachment = attach.*;

            dsv_handle = try self.command_buffer.allocateDsvDescriptor();

            self.device.device.?.ID3D12Device_CreateDepthStencilView(
                texture.resource.d3d_resource,
                null,
                dsv_handle,
            );
        }

        self.barrier_enforcer.flush(command_list);

        command_list.ID3D12GraphicsCommandList_OMSetRenderTargets(
            @intCast((desc.colour_attachments orelse &.{}).len),
            &rtv_handles,
            TRUE,
            if (desc.depth_stencil_attachment != null) &dsv_handle else null,
        );

        rtv_handle = rtv_handles;
        for (desc.colour_attachments orelse &.{}) |attach| {
            if (attach.load_op == .clear) {
                const clear_color = [4]f32{
                    @floatCast(attach.clear_value.r),
                    @floatCast(attach.clear_value.g),
                    @floatCast(attach.clear_value.b),
                    @floatCast(attach.clear_value.a),
                };
                command_list.ID3D12GraphicsCommandList_ClearRenderTargetView(
                    rtv_handle,
                    &clear_color,
                    0,
                    null,
                );
            }

            rtv_handle.ptr += descriptor_size;
        }

        if (desc.depth_stencil_attachment) |attach| {
            var clear_flags: d3d12.D3D12_CLEAR_FLAGS = 0;

            if (attach.depth_load_op == .clear)
                clear_flags |= d3d12.D3D12_CLEAR_FLAG_DEPTH;
            if (attach.stencil_load_op == .clear)
                clear_flags |= d3d12.D3D12_CLEAR_FLAG_STENCIL;

            if (clear_flags != 0) {
                command_list.ID3D12GraphicsCommandList_ClearDepthStencilView(
                    dsv_handle,
                    clear_flags,
                    attach.depth_clear_value,
                    @intCast(attach.stencil_clear_value),
                    0,
                    null,
                );
            }
        }

        const viewport = d3d12.D3D12_VIEWPORT{
            .TopLeftX = 0,
            .TopLeftY = 0,
            .Width = @floatFromInt(width),
            .Height = @floatFromInt(height),
            .MinDepth = 0,
            .MaxDepth = 1,
        };
        const scissor_rect = d3d12.D3D12_RECT{
            .left = 0,
            .top = 0,
            .right = @intCast(width),
            .bottom = @intCast(height),
        };

        command_list.ID3D12GraphicsCommandList_RSSetViewports(1, &viewport);
        command_list.ID3D12GraphicsCommandList_RSSetScissorRects(1, &scissor_rect);

        // Result
        const encoder = try allocator.create(D3D12RenderPassEncoder);
        encoder.* = .{
            .command_list = command_list,
            .color_attachments = color_attachments,
            .depth_attachment = depth_attachment,
            .barrier_enforcer = &self.barrier_enforcer,
            .vertex_buffer_views = std.mem.zeroes([gpu.Limits.max_vertex_buffers]d3d12.D3D12_VERTEX_BUFFER_VIEW),
        };
        return encoder;
    }

    pub fn deinit(encoder: *D3D12RenderPassEncoder) void {
        allocator.destroy(encoder);
    }

    pub fn draw(
        encoder: *D3D12RenderPassEncoder,
        vertex_count: u32,
        instance_count: u32,
        first_vertex: u32,
        first_instance: u32,
    ) void {
        const command_list = encoder.command_list.?;

        encoder.applyVertexBuffers();

        command_list.ID3D12GraphicsCommandList_DrawInstanced(
            vertex_count,
            instance_count,
            first_vertex,
            first_instance,
        );
    }

    pub fn drawIndexed(
        encoder: *D3D12RenderPassEncoder,
        index_count: u32,
        instance_count: u32,
        first_index: u32,
        base_vertex: i32,
        first_instance: u32,
    ) void {
        const command_list = encoder.command_list.?;

        encoder.applyVertexBuffers();

        command_list.ID3D12GraphicsCommandList_DrawIndexedInstanced(
            index_count,
            instance_count,
            first_index,
            base_vertex,
            first_instance,
        );
    }

    pub fn end(encoder: *D3D12RenderPassEncoder) !void {
        const command_list = encoder.command_list.?;

        for (encoder.color_attachments.slice()) |attach| {
            const view: *D3D12TextureView = @ptrCast(@alignCast(attach.view.?));

            if (attach.resolve_target) |resolve_target_raw| {
                const resolve_target: *D3D12TextureView = @ptrCast(@alignCast(resolve_target_raw));

                encoder.barrier_enforcer.transition(
                    &view.texture.resource.?,
                    d3d12.D3D12_RESOURCE_STATE_RESOLVE_SOURCE,
                ) catch
                    return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToEnd;
                encoder.barrier_enforcer.transition(
                    &resolve_target.texture.resource.?,
                    d3d12.D3D12_RESOURCE_STATE_RESOLVE_DEST,
                ) catch
                    return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToEnd;

                encoder.barrier_enforcer.flush(command_list);

                // Format
                const resolve_d3d_resource = resolve_target.texture.resource.?.resource.?;
                const view_d3d_resource = view.texture.resource.?.resource.?;

                var format: dxgi.common.DXGI_FORMAT = undefined;
                var d3d_desc = resolve_d3d_resource.ID3D12Resource_GetDesc();
                format = d3d_desc.Format;
                if (d3dcommon.dxgiFormatIsTypeless(format)) {
                    d3d_desc = view_d3d_resource.ID3D12Resource_GetDesc();
                    format = d3d_desc.Format;
                    if (d3dcommon.dxgiFormatIsTypeless(format)) {
                        return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToEnd;
                    }
                }

                command_list.ID3D12GraphicsCommandList_ResolveSubresource(
                    resolve_target.texture.resource.?.resource,
                    resolve_target.base_subresource,
                    view.texture.resource.?.resource,
                    view.base_subresource,
                    format,
                );

                encoder.barrier_enforcer.transition(
                    &resolve_target.texture.resource.?,
                    resolve_target.texture.resource.?.read_state,
                ) catch
                    return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToEnd;
            }

            encoder.barrier_enforcer.transition(
                &view.texture.resource.?,
                view.texture.resource.?.read_state,
            ) catch
                return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToEnd;
        }

        if (encoder.depth_attachment) |attach| {
            const view: *D3D12TextureView = @ptrCast(@alignCast(attach.view));

            encoder.barrier_enforcer.transition(
                &view.texture.resource.?,
                view.texture.resource.?.read_state,
            ) catch
                return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToEnd;
        }
    }

    pub fn setBindGroup(
        encoder: *D3D12RenderPassEncoder,
        group_index: u32,
        group: *D3D12BindGroup,
        dynamic_offsets: ?[]const u32,
    ) void {
        const command_list = encoder.command_list.?;

        var parameter_index = encoder.group_parameter_indices[group_index];

        if (group.general_table) |table| {
            command_list.ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(
                parameter_index,
                table,
            );
            parameter_index += 1;
        }

        if (group.sampler_table) |table| {
            command_list.ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(
                parameter_index,
                table,
            );
            parameter_index += 1;
        }

        for (dynamic_offsets orelse &.{}, 0..) |dynamic_offset, i| {
            const dynamic_resource = group.dynamic_resources[i];

            switch (dynamic_resource.parameter_type) {
                d3d12.D3D12_ROOT_PARAMETER_TYPE_CBV => command_list.ID3D12GraphicsCommandList_SetGraphicsRootConstantBufferView(
                    parameter_index,
                    dynamic_resource.address + dynamic_offset,
                ),
                d3d12.D3D12_ROOT_PARAMETER_TYPE_SRV => command_list.ID3D12GraphicsCommandList_SetGraphicsRootShaderResourceView(
                    parameter_index,
                    dynamic_resource.address + dynamic_offset,
                ),
                d3d12.D3D12_ROOT_PARAMETER_TYPE_UAV => command_list.ID3D12GraphicsCommandList_SetGraphicsRootUnorderedAccessView(
                    parameter_index,
                    dynamic_resource.address + dynamic_offset,
                ),
                else => {},
            }

            parameter_index += 1;
        }
    }

    pub fn setIndexBuffer(
        encoder: *D3D12RenderPassEncoder,
        buffer: *D3D12Buffer,
        format: gpu.IndexFormat,
        offset: u64,
        size: u64,
    ) !void {
        const command_list = encoder.command_list.?;
        const d3d_resource = buffer.buffer.resource.?;

        const d3d_size: u32 = @intCast(if (size == gpu.whole_size) buffer.size - offset else size);

        command_list.ID3D12GraphicsCommandList_IASetIndexBuffer(
            &d3d12.D3D12_INDEX_BUFFER_VIEW{
                .BufferLocation = d3d_resource.ID3D12Resource_GetGPUVirtualAddress() + offset,
                .SizeInBytes = d3d_size,
                .Format = switch (format) {
                    .undefined => unreachable,
                    .uint16 => .R16_UINT,
                    .uint32 => .R32_UINT,
                },
            },
        );
    }

    pub fn setPipeline(encoder: *D3D12RenderPassEncoder, pipeline: *D3D12RenderPipeline) !void {
        _ = pipeline;

        const command_list = encoder.command_list.?;
        _ = command_list;

        // encoder.group_parameter_indices = pipeline.layout.group_parameter_indices.slice();
        // encoder.vertex_strides = pipeline.vertex_strides.slice();

        // command_list.ID3D12GraphicsCommandList_SetGraphicsRootSignature(
        //     pipeline.layout.root_signature,
        // );

        // command_list.ID3D12GraphicsCommandList_SetPipelineState(
        //     pipeline.d3d_pipeline,
        // );

        // command_list.ID3D12GraphicsCommandList_IASetPrimitiveTopology(
        //     pipeline.topology,
        // );
    }

    pub fn setScissorRect(encoder: *D3D12RenderPassEncoder, x: u32, y: u32, width: u32, height: u32) !void {
        const command_list = encoder.command_list.?;

        const scissor_rect = win32.foundation.RECT{
            .left = @intCast(x),
            .top = @intCast(y),
            .right = @intCast(x + width),
            .bottom = @intCast(y + height),
        };

        command_list.ID3D12GraphicsCommandList_RSSetScissorRects(1, @ptrCast(&scissor_rect));
    }

    pub fn setVertexBuffer(encoder: *D3D12RenderPassEncoder, slot: u32, buffer: *D3D12Buffer, offset: u64, size: u64) !void {
        const d3d_resource = buffer.buffer.resource.?;

        var view = &encoder.vertex_buffer_views[slot];
        view.BufferLocation = d3d_resource.ID3D12Resource_GetGPUVirtualAddress() + offset;
        view.SizeInBytes = @intCast(size);
        // StrideInBytes deferred until draw()

        encoder.vertex_apply_count = @max(encoder.vertex_apply_count, slot + 1);
    }

    pub fn setViewport(
        encoder: *D3D12RenderPassEncoder,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        min_depth: f32,
        max_depth: f32,
    ) !void {
        const command_list = encoder.command_list.?;

        const viewport = d3d12.D3D12_VIEWPORT{
            .TopLeftX = x,
            .TopLeftY = y,
            .Width = width,
            .Height = height,
            .MinDepth = min_depth,
            .MaxDepth = max_depth,
        };

        command_list.ID3D12GraphicsCommandList_RSSetViewports(1, @ptrCast(&viewport));
    }

    // Private
    fn applyVertexBuffers(encoder: *D3D12RenderPassEncoder) void {
        if (encoder.vertex_apply_count > 0) {
            const command_list = encoder.command_list.?;

            for (0..encoder.vertex_apply_count) |i| {
                var view = &encoder.vertex_buffer_views[i];
                view.StrideInBytes = encoder.vertex_strides[i];
            }

            command_list.ID3D12GraphicsCommandList_IASetVertexBuffers(
                0,
                encoder.vertex_apply_count,
                &encoder.vertex_buffer_views,
            );

            encoder.vertex_apply_count = 0;
        }
    }
};

// RenderPipeline
pub const D3D12RenderPipeline = struct {
    layout: *D3D12PipelineLayout,
};

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
        filter |= @intFromEnum(d3d12FilterType(min_filter)) << d3d12.D3D12_MIN_FILTER_SHIFT;
        filter |= @intFromEnum(d3d12FilterType(mag_filter)) << d3d12.D3D12_MAG_FILTER_SHIFT;
        filter |= @intFromEnum(d3d12FilterTypeForMipmap(mipmap_filter)) << d3d12.D3D12_MIP_FILTER_SHIFT;
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

    pub fn getCurrentTextureView(self: *D3D12SwapChain) !*D3D12TextureView {
        const fence_value = self.fences[self.current_index];
        _ = self.device.queue.waitUntil(fence_value);

        const index = self.swapchain.?.IDXGISwapChain3_GetCurrentBackBufferIndex();
        self.current_index = index;
        return self.views[index].?;
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
            .Format = if ((if (desc.view_formats) |vf| vf.len else 0) > 0)
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
                .ALLOW_UNORDERED_ACCESS = if (desc.usage.storage_binding) 1 else 0,
                .DENY_SHADER_RESOURCE = if (!desc.usage.texture_binding and
                    desc.usage.render_attachment and
                    desc.format.hasDepthOrStencil()) 1 else 0,
            }),
        };
        const read_state = d3d12.D3D12_RESOURCE_STATES.initFlags(.{
            .COPY_SOURCE = if (desc.usage.copy_src) 1 else 0,
            .ALL_SHADER_RESOURCE = if (desc.usage.texture_binding or desc.usage.storage_binding) 1 else 0,
        });
        const initial_state = read_state;

        const clear_value = d3d12.D3D12_CLEAR_VALUE{
            .Format = resource_desc.Format,
            .Anonymous = .{
                .Color = .{ 0, 0, 0, 0 },
            },
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
