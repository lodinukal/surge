const std = @import("std");
const gpu = @import("gpu");

const winapi = @import("win32");
const win32 = winapi.windows.win32;
const d3d = win32.graphics.direct3d;
const d3d12 = win32.graphics.direct3d12;
const dxgi = win32.graphics.dxgi;
const hlsl = win32.graphics.hlsl;
const dxc = d3d.dxc;

const gpu_allocator = gpu.allocator;

const upload_page_size = 64 * 1024 * 1024; // TODO - split writes and/or support large uploads
const max_back_buffer_count = 3;

const TRUE = win32.foundation.TRUE;
const FALSE = win32.foundation.FALSE;

const winappimpl = @import("app").platform.impl;

const d3dcommon = @import("d3d");

const ScratchSpace = @import("core").allocators.ScratchSpace;

const descriptor = @import("descriptor.zig");

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
    .commandEncoderBeginRenderPass = commandEncoderBeginRenderPass,
    .commandEncoderFinish = commandEncoderFinish,
    .commandEncoderDestroy = commandEncoderDestroy,
    // ComputePassEncoder
    // ComputePipeline
    // Device
    .deviceCreateBindGroup = deviceCreateBindGroup,
    .deviceCreateBindGroupLayout = deviceCreateBindGroupLayout,
    .deviceCreatePipelineLayout = deviceCreatePipelineLayout,
    .deviceCreateRenderPipeline = deviceCreateRenderPipeline,
    .deviceCreateBuffer = deviceCreateBuffer,
    .deviceCreateCommandEncoder = deviceCreateCommandEncoder,
    .deviceCreateSampler = deviceCreateSampler,
    .deviceCreateShaderModule = deviceCreateShaderModule,
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
    .queueWriteBuffer = queueWriteBuffer,
    .queueWriteTexture = queueWriteTexture,
    .queueWaitIdle = queueWaitIdle,
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
    .renderPipelineDestroy = renderPipelineDestroy,
    // Sampler
    .samplerDestroy = samplerDestroy,
    // ShaderModule
    .shaderModuleDestroy = shaderModuleDestroy,
    // Surface
    .surfaceDestroy = surfaceDestroy,
    // SwapChain
    .swapChainGetIndex = swapChainGetIndex,
    .swapChainGetCurrentTexture = swapChainGetCurrentTexture,
    .swapChainGetCurrentTextureView = swapChainGetCurrentTextureView,
    .swapChainGetTextureViews = swapChainGetTextureViews,
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

fn setDebugName(comptime T: type, child: ?*T, name: []const u8) void {
    if (child) |c| {
        const hr = c.ID3D12Object_SetPrivateData(
            &d3d.WKPDID_D3DDebugObjectName,
            @intCast(name.len),
            @ptrCast(@alignCast(name)),
        );
        if (!d3dcommon.checkHResult(hr))
            std.debug.panic("Failed to set debug name for D3D12 object: {s}", .{name});
    }
}

// BindGroup
pub fn bindGroupDestroy(bind_group: *gpu.BindGroup) void {
    D3D12BindGroup.destroy(@alignCast(@ptrCast(bind_group)));
}

pub const D3D12BindGroup = struct {
    const ResourceAccess = struct {
        resource: *const D3D12Resource,
        uav: bool,
    };
    const DynamicResource = struct {
        address: u64, // d3d12.D3D12_GPU_VIRTUAL_ADDRESS
        parameter_type: d3d12.D3D12_ROOT_PARAMETER_TYPE,
    };

    allocator: std.mem.Allocator,
    device: *D3D12Device,
    view_descriptor: ?descriptor.DescriptorIndex,
    view_table: ?descriptor.DualHandle,
    sampler_descriptor: ?descriptor.DescriptorIndex,
    sampler_table: ?descriptor.DualHandle,
    dynamic_resources: []DynamicResource,
    buffers: std.ArrayListUnmanaged(*const D3D12Buffer),
    textures: std.ArrayListUnmanaged(*const D3D12Texture),
    accesses: std.ArrayListUnmanaged(ResourceAccess),

    pub fn create(allocator: std.mem.Allocator, device: *D3D12Device, desc: *const gpu.BindGroup.Descriptor) !*D3D12BindGroup {
        const layout: *D3D12BindGroupLayout = @ptrCast(@alignCast(desc.layout));

        // General Descriptor Table
        var view_descriptor: ?descriptor.DescriptorIndex = null;
        var view_table: ?descriptor.DualHandle = null;

        if (layout.view_table_size > 0) {
            const descriptor_index = device.heap_views.alloc(layout.view_table_size) catch
                return gpu.BindGroup.Error.BindGroupFailedToCreate;
            view_descriptor = descriptor_index;
            view_table = device.heap_views.at(descriptor_index, layout.view_table_size);

            for (desc.entries) |entry| {
                const layout_entry = layout.getEntry(entry.binding) orelse
                    return gpu.BindGroup.Error.BindGroupUnknownBinding;
                if (std.meta.activeTag(layout_entry.entry.type) == .sampler)
                    continue;

                if (layout_entry.table_index) |table_index| {
                    const dest_descriptor_base = descriptor_index + table_index;

                    switch (layout_entry.entry.type) {
                        .buffer => |buffer_layout| {
                            if (std.meta.activeTag(entry.type) != .buffers)
                                return gpu.BindGroup.Error.BindGroupMismatchedBindingType;
                            for (entry.type.buffers, 0..) |buffer_binding, idx| {
                                const dest_descriptor = device.heap_views.cpuDescriptorAt(dest_descriptor_base + idx);

                                const size = buffer_binding.resolveSize();
                                const buffer: *D3D12Buffer = @ptrCast(@alignCast(buffer_binding.buffer));
                                const d3d_resource = buffer.buffer.resource.?;

                                const buffer_location = d3d_resource.ID3D12Resource_GetGPUVirtualAddress() + buffer_binding.offset;

                                switch (buffer_layout.type) {
                                    .undefined => unreachable,
                                    .uniform => {
                                        const cbv_desc: d3d12.D3D12_CONSTANT_BUFFER_VIEW_DESC = .{
                                            .BufferLocation = buffer_location,
                                            .SizeInBytes = @intCast(gpu.util.alignUp(size, gpu.Limits.min_uniform_buffer_offset_alignment)),
                                        };

                                        device.device.?.ID3D12Device_CreateConstantBufferView(
                                            &cbv_desc,
                                            dest_descriptor,
                                        );
                                    },
                                    .storage => {
                                        const uav_desc: d3d12.D3D12_UNORDERED_ACCESS_VIEW_DESC = .{
                                            .Format = .UNKNOWN,
                                            .ViewDimension = d3d12.D3D12_UAV_DIMENSION_BUFFER,
                                            .Anonymous = .{
                                                .Buffer = .{
                                                    .FirstElement = @intCast(buffer_binding.offset / 4),
                                                    .NumElements = @intCast(size / 4),
                                                    .StructureByteStride = 0,
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
                                        const srv_desc: d3d12.D3D12_SHADER_RESOURCE_VIEW_DESC = .{
                                            .Format = dxgi.common.DXGI_FORMAT_UNKNOWN,
                                            .ViewDimension = d3d12.D3D12_SRV_DIMENSION_BUFFER,
                                            .Shader4ComponentMapping = d3d12.D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING,
                                            .Anonymous = .{
                                                .Buffer = .{
                                                    .FirstElement = @intCast(buffer_binding.offset / 4),
                                                    .NumElements = @intCast(size / 4),
                                                    .StructureByteStride = 0,
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
                            }
                        },
                        .texture => |texture_layout| {
                            _ = texture_layout;

                            if (std.meta.activeTag(entry.type) != .texture_views)
                                return gpu.BindGroup.Error.BindGroupMismatchedBindingType;

                            for (entry.type.texture_views, 0..) |raw_texture_view, idx| {
                                const dest_descriptor = device.heap_views.cpuDescriptorAt(dest_descriptor_base + idx);

                                const texture_view: *D3D12TextureView = @ptrCast(@alignCast(raw_texture_view));
                                const d3d_resource = texture_view.texture.resource.?.resource;

                                device.device.?.ID3D12Device_CreateShaderResourceView(
                                    d3d_resource,
                                    &texture_view.srvDesc(),
                                    dest_descriptor,
                                );
                            }
                        },
                        .storage_texture => |storage_texture_layout| {
                            _ = storage_texture_layout;

                            if (std.meta.activeTag(entry.type) != .texture_views)
                                return gpu.BindGroup.Error.BindGroupMismatchedBindingType;

                            for (entry.type.texture_views, 0..) |raw_texture_view, idx| {
                                const dest_descriptor = device.heap_views.cpuDescriptorAt(dest_descriptor_base + idx);

                                const texture_view: *D3D12TextureView = @ptrCast(@alignCast(raw_texture_view));
                                const d3d_resource = texture_view.texture.resource.?.resource;

                                device.device.?.ID3D12Device_CreateUnorderedAccessView(
                                    d3d_resource,
                                    null,
                                    &texture_view.uavDesc(),
                                    dest_descriptor,
                                );
                            }
                        },
                        else => unreachable,
                    }
                }
            }
        }

        // Sampler Descriptor Table
        var sampler_descriptor: ?descriptor.DescriptorIndex = null;
        var sampler_table: ?descriptor.DualHandle = null;

        if (layout.sampler_table_size > 0) {
            const descriptor_index = device.heap_samplers.alloc(layout.sampler_table_size) catch
                return gpu.BindGroup.Error.BindGroupFailedToCreate;
            sampler_descriptor = descriptor_index;
            sampler_table = device.heap_samplers.at(descriptor_index, layout.sampler_table_size);

            for (desc.entries) |entry| {
                const layout_entry = layout.getEntry(entry.binding) orelse
                    return gpu.BindGroup.Error.BindGroupUnknownBinding;
                if (std.meta.activeTag(entry.type) != .samplers)
                    continue;

                if (layout_entry.table_index) |table_index| {
                    const dest_descriptor_base = descriptor_index + table_index;

                    for (entry.type.samplers, 0..) |raw_sampler, idx| {
                        const dest_descriptor = device.heap_samplers.cpuDescriptorAt(dest_descriptor_base + idx);

                        const sampler: *D3D12Sampler = @ptrCast(@alignCast(raw_sampler));

                        device.device.?.ID3D12Device_CreateSampler(
                            &sampler.desc,
                            dest_descriptor,
                        );
                    }
                }
            }
        }

        // Resource tracking and dynamic resources
        var dynamic_resources = allocator.alloc(DynamicResource, layout.dynamic_entries.items.len) catch
            return gpu.BindGroup.Error.BindGroupFailedToCreate;
        errdefer allocator.free(dynamic_resources);

        var buffers = std.ArrayListUnmanaged(*const D3D12Buffer){};
        errdefer buffers.deinit(allocator);

        var textures = std.ArrayListUnmanaged(*const D3D12Texture){};
        errdefer textures.deinit(allocator);

        var accesses = std.ArrayListUnmanaged(ResourceAccess){};
        errdefer accesses.deinit(allocator);

        for (desc.entries) |entry| {
            const layout_entry = layout.getEntry(entry.binding) orelse
                return gpu.BindGroup.Error.BindGroupUnknownBinding;

            switch (layout_entry.entry.type) {
                .buffer => |buffer_layout| {
                    if (std.meta.activeTag(entry.type) != .buffers)
                        return gpu.BindGroup.Error.BindGroupMismatchedBindingType;

                    for (entry.type.buffers, 0..) |buffer_binding, idx| {
                        _ = idx;

                        const buffer: *D3D12Buffer = @ptrCast(@alignCast(buffer_binding.buffer));
                        const d3d_resource = buffer.buffer.resource.?;

                        buffers.append(allocator, buffer) catch
                            return gpu.BindGroup.Error.BindGroupFailedToCreate;

                        const buffer_location = d3d_resource.ID3D12Resource_GetGPUVirtualAddress() + buffer_binding.offset;
                        if (layout_entry.dynamic_index) |dynamic_index| {
                            const layout_dynamic_entry = layout.dynamic_entries.items[dynamic_index];
                            dynamic_resources[dynamic_index] = .{
                                .address = buffer_location,
                                .parameter_type = layout_dynamic_entry.parameter_type,
                            };
                        }

                        accesses.append(allocator, .{
                            .resource = &buffer.buffer,
                            .uav = buffer_layout.type == .storage,
                        }) catch
                            return gpu.BindGroup.Error.BindGroupFailedToCreate;
                    }
                },
                .sampler => |sampler_layout| {
                    _ = sampler_layout;
                },
                .texture => |texture_layout| {
                    _ = texture_layout;

                    for (entry.type.texture_views, 0..) |raw_texture_view, idx| {
                        _ = idx;

                        const texture_view: *D3D12TextureView = @ptrCast(@alignCast(raw_texture_view));
                        const texture = texture_view.texture;

                        textures.append(allocator, texture) catch
                            return gpu.BindGroup.Error.BindGroupFailedToCreate;

                        accesses.append(allocator, .{ .resource = &texture.resource.?, .uav = false }) catch
                            return gpu.BindGroup.Error.BindGroupFailedToCreate;
                    }
                },
                .storage_texture => |storage_texture_layout| {
                    _ = storage_texture_layout;

                    for (entry.type.texture_views, 0..) |raw_texture_view, idx| {
                        _ = idx;

                        const texture_view: *D3D12TextureView = @ptrCast(@alignCast(raw_texture_view));
                        const texture = texture_view.texture;

                        textures.append(allocator, texture) catch
                            return gpu.BindGroup.Error.BindGroupFailedToCreate;

                        accesses.append(allocator, .{ .resource = &texture.resource.?, .uav = true }) catch
                            return gpu.BindGroup.Error.BindGroupFailedToCreate;
                    }
                },
            }
        }

        const group = allocator.create(D3D12BindGroup) catch
            return gpu.BindGroup.Error.BindGroupFailedToCreate;
        group.* = .{
            .allocator = allocator,
            .device = device,
            .view_descriptor = view_descriptor,
            .view_table = view_table,
            .sampler_descriptor = sampler_descriptor,
            .sampler_table = sampler_table,
            .dynamic_resources = dynamic_resources,
            .buffers = buffers,
            .textures = textures,
            .accesses = accesses,
        };
        return group;
    }

    pub fn destroy(self: *D3D12BindGroup) void {
        if (self.view_table) |handle|
            self.device.heap_views.free(handle);
        if (self.sampler_table) |handle|
            self.device.heap_samplers.free(handle);

        self.buffers.deinit(self.allocator);
        self.textures.deinit(self.allocator);
        self.accesses.deinit(self.allocator);
        self.allocator.free(self.dynamic_resources);
        self.allocator.destroy(self);
    }
};

// BindGroupLayout
pub fn bindGroupLayoutDestroy(bind_group_layout: *gpu.BindGroupLayout) void {
    D3D12BindGroupLayout.destroy(@alignCast(@ptrCast(bind_group_layout)));
}

pub const D3D12BindGroupLayout = struct {
    const Entry = struct {
        entry: gpu.BindGroupLayout.Entry,
        range_type: d3d12.D3D12_DESCRIPTOR_RANGE_TYPE,
        table_index: ?u32,
        dynamic_index: ?u32,
    };

    const DynamicEntry = struct {
        parameter_type: d3d12.D3D12_ROOT_PARAMETER_TYPE,
    };

    allocator: std.mem.Allocator,
    entries: std.ArrayListUnmanaged(Entry),
    dynamic_entries: std.ArrayListUnmanaged(DynamicEntry),
    view_table_size: u32,
    sampler_table_size: u32,

    pub fn create(allocator: std.mem.Allocator, device: *D3D12Device, desc: *const gpu.BindGroupLayout.Descriptor) !*D3D12BindGroupLayout {
        _ = device;

        var entries = std.ArrayListUnmanaged(Entry){};
        errdefer entries.deinit(allocator);

        var dynamic_entries = std.ArrayListUnmanaged(DynamicEntry){};
        errdefer dynamic_entries.deinit(allocator);

        var view_table_size: u32 = 0;
        var sampler_table_size: u32 = 0;
        for (desc.entries) |entry| {
            var table_index: ?u32 = null;
            var dynamic_index: ?u32 = null;
            switch (entry.type) {
                .buffer => |buffer| {
                    if (buffer.has_dynamic_offset) {
                        dynamic_index = @intCast(dynamic_entries.items.len);
                        dynamic_entries.append(allocator, .{
                            .parameter_type = switch (buffer.type) {
                                .undefined => unreachable,
                                .uniform => d3d12.D3D12_ROOT_PARAMETER_TYPE_CBV,
                                .storage => d3d12.D3D12_ROOT_PARAMETER_TYPE_UAV,
                                .read_only_storage => d3d12.D3D12_ROOT_PARAMETER_TYPE_SRV,
                            },
                        }) catch return gpu.BindGroupLayout.Error.BindGroupLayoutFailedToCreate;
                    } else {
                        table_index = view_table_size;
                        view_table_size += entry.count orelse 1;
                    }
                },
                .sampler => {
                    table_index = sampler_table_size;
                    sampler_table_size += entry.count orelse 1;
                },
                else => {
                    table_index = view_table_size;
                    view_table_size += entry.count orelse 1;
                },
            }

            entries.append(allocator, .{
                .entry = entry,
                .range_type = switch (entry.type) {
                    .buffer => |buffer| switch (buffer.type) {
                        .undefined => unreachable,
                        .uniform => d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_CBV,
                        .storage => d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_UAV,
                        .read_only_storage => d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_SRV,
                    },
                    .sampler => d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_SAMPLER,
                    .texture => d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_SRV,
                    else => d3d12.D3D12_DESCRIPTOR_RANGE_TYPE_UAV,
                },
                .table_index = table_index,
                .dynamic_index = dynamic_index,
            }) catch return gpu.BindGroupLayout.Error.BindGroupLayoutFailedToCreate;
        }

        const layout = allocator.create(D3D12BindGroupLayout) catch
            return gpu.BindGroupLayout.Error.BindGroupLayoutFailedToCreate;
        layout.* = .{
            .allocator = allocator,
            .entries = entries,
            .dynamic_entries = dynamic_entries,
            .view_table_size = view_table_size,
            .sampler_table_size = sampler_table_size,
        };
        return layout;
    }

    pub fn destroy(self: *D3D12BindGroupLayout) void {
        self.entries.deinit(self.allocator);
        self.dynamic_entries.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn getEntry(self: *D3D12BindGroupLayout, binding: u32) ?*const Entry {
        for (self.entries.items) |*entry| {
            if (entry.entry.binding == binding)
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
    return D3D12Buffer.map(@ptrCast(@alignCast(buffer))) catch return gpu.Buffer.Error.BufferMapFailed;
}

pub fn bufferUnmap(buffer: *gpu.Buffer) void {
    D3D12Buffer.unmap(@ptrCast(@alignCast(buffer)));
}

pub fn bufferGetMappedRange(buffer: *gpu.Buffer, offset: usize, size: ?usize) gpu.Buffer.Error![]u8 {
    return D3D12Buffer.getMappedRange(@ptrCast(@alignCast(buffer)), offset, size, true);
}

pub fn bufferGetMappedRangeConst(buffer: *gpu.Buffer, offset: usize, size: ?usize) gpu.Buffer.Error![]const u8 {
    return D3D12Buffer.getMappedRange(@ptrCast(@alignCast(buffer)), offset, size, false);
}

pub fn bufferDestroy(buffer: *gpu.Buffer) void {
    D3D12Buffer.destroy(@alignCast(@ptrCast(buffer)));
}

pub const D3D12Buffer = struct {
    allocator: std.mem.Allocator,
    device: *D3D12Device,

    size: u64,
    usage: gpu.Buffer.UsageFlags,

    staging_buffer: ?*D3D12Buffer = null, // used for initial mapping
    buffer: D3D12Resource,

    mapped: ?[]u8 = null,
    mapped_at_creation: bool = false,

    pub fn create(allocator: std.mem.Allocator, device: *D3D12Device, desc: *const gpu.Buffer.Descriptor) gpu.Buffer.Error!*D3D12Buffer {
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
                stage = try D3D12Buffer.create(allocator, device, &.{
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
            .allocator = allocator,
            .device = device,
            .size = desc.size,
            .usage = desc.usage,
            .staging_buffer = stage,
            .buffer = resource,
            .mapped = if (mapped) |m| @ptrCast(
                @as([*]u8, @ptrCast(m))[0..desc.size],
            ) else null,
        };

        if (desc.label) |name| {
            self.setLabel(name);
        }

        return self;
    }

    pub fn destroy(self: *D3D12Buffer) void {
        if (self.staging_buffer) |sb| sb.destroy();
        self.buffer.deinit();
        self.allocator.destroy(self);
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

    pub fn setLabel(self: *D3D12Buffer, name: []const u8) void {
        setDebugName(d3d12.ID3D12Resource, self.buffer.resource, name);
        if (self.staging_buffer) |sb| {
            var scratch = ScratchSpace(2048){};
            const temp_allocator = scratch.init().allocator();
            sb.setLabel(std.fmt.allocPrint(
                temp_allocator,
                "{s}_staging",
                .{name},
            ) catch "?_staging");
        }
    }
};

// CommandBuffer
pub fn commandBufferDestroy(command_buffer: *gpu.CommandBuffer) void {
    D3D12CommandBuffer.destroy(@alignCast(@ptrCast(command_buffer)));
}

pub const D3D12CommandBuffer = struct {
    pub const StreamingResult = struct {
        resource: ?*d3d12.ID3D12Resource,
        map: []u8,
        offset: u32,
    };

    allocator: std.mem.Allocator,
    device: *D3D12Device,
    command_allocator: ?*d3d12.ID3D12CommandAllocator = null,
    command_list: ?*d3d12.ID3D12GraphicsCommandList = null,
    upload_buffer: ?D3D12Resource = null,
    upload_map: ?[*]u8 = null,
    upload_next_offset: u32 = upload_page_size,

    pub fn create(
        allocator: std.mem.Allocator,
        device: *D3D12Device,
    ) gpu.CommandBuffer.Error!*D3D12CommandBuffer {
        const command_allocator = device.command_pool.createCommandAllocator() catch
            return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        errdefer device.command_pool.destroyCommandAllocator(command_allocator);

        const command_list = device.command_pool.createCommandList(command_allocator) catch
            return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        errdefer device.command_pool.destroyCommandList(command_list);

        var heaps = [2]*d3d12.ID3D12DescriptorHeap{
            device.heap_views.heap.?,
            device.heap_samplers.heap.?,
        };
        command_list.ID3D12GraphicsCommandList_SetDescriptorHeaps(2, @ptrCast(&heaps));

        const self = allocator.create(
            D3D12CommandBuffer,
        ) catch return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        self.* = .{
            .allocator = allocator,
            .device = device,
            .command_allocator = command_allocator,
            .command_list = command_list,
        };

        return self;
    }

    pub fn destroy(self: *D3D12CommandBuffer) void {
        self.deinit();
        self.allocator.destroy(self);
    }

    pub fn deinit(self: *D3D12CommandBuffer) void {
        // unsubmitted CommandBuffer
        if (self.command_list) |cl| self.device.command_pool.destroyCommandList(cl);
        if (self.command_allocator) |ca| self.device.command_pool.destroyCommandAllocator(ca);
        self.releaseUploadBuffer();
    }

    fn releaseUploadBuffer(self: *D3D12CommandBuffer) void {
        if (self.upload_buffer) |ub| {
            ub.resource.?.ID3D12Resource_Unmap(0, null);
            self.device.streaming_pool.release(ub);
        }
    }

    pub fn upload(self: *D3D12CommandBuffer, size: u64) !StreamingResult {
        std.debug.print("eeee\n", .{});
        if (self.upload_next_offset + size > upload_page_size) {
            self.releaseUploadBuffer();
            std.debug.assert(size <= upload_page_size);
            const resource = try self.device.streaming_pool.acquire();

            // TODO: find a way to name this
            self.upload_buffer = resource;

            var map: ?*anyopaque = null;
            const hr_map = resource.resource.?.ID3D12Resource_Map(0, null, &map);
            if (!d3dcommon.checkHResult(hr_map)) return gpu.CommandBuffer.Error.CommandBufferMapForUploadFailed;

            self.upload_map = @ptrCast(map);
            self.upload_next_offset = 0;
        }

        const offset = self.upload_next_offset;
        self.upload_next_offset = @intCast(
            gpu.util.alignUp(
                offset + size,
                gpu.Limits.min_uniform_buffer_offset_alignment,
            ),
        );

        return .{
            .resource = self.upload_buffer.?.resource.?,
            .map = self.upload_map.?[offset .. offset + size],
            .offset = offset,
        };
    }

    pub fn setLabel(self: *D3D12CommandBuffer, name: []const u8) void {
        var scratch = ScratchSpace(4096){};
        const temp_allocator = scratch.init().allocator();

        const command_allocator_name = std.fmt.allocPrint(
            temp_allocator,
            "{s}_command_allocator",
            .{name},
        ) catch "commandbuffer_command_allocator";
        setDebugName(d3d12.ID3D12CommandAllocator, self.command_allocator, command_allocator_name);
        scratch.fba.reset();

        const command_list_name = std.fmt.allocPrint(
            temp_allocator,
            "{s}_command_list",
            .{name},
        ) catch "commandbuffer_command_list";
        setDebugName(d3d12.ID3D12GraphicsCommandList, self.command_list, command_list_name);
        scratch.fba.reset();
    }
};

// CommandEncoder
pub fn commandEncoderBeginRenderPass(
    command_encoder: *gpu.CommandEncoder,
    allocator: std.mem.Allocator,
    desc: *const gpu.RenderPass.Descriptor,
) gpu.RenderPass.Encoder.Error!*gpu.RenderPass.Encoder {
    return @ptrCast(try D3D12CommandEncoder.beginRenderPass(
        @ptrCast(@alignCast(command_encoder)),
        allocator,
        desc,
    ));
}

pub fn commandEncoderFinish(
    command_encoder: *gpu.CommandEncoder,
    desc: *const gpu.CommandBuffer.Descriptor,
) gpu.CommandBuffer.Error!*gpu.CommandBuffer {
    return @ptrCast(try D3D12CommandEncoder.finish(
        @ptrCast(@alignCast(command_encoder)),
        desc,
    ));
}

pub fn commandEncoderDestroy(command_encoder: *gpu.CommandEncoder) void {
    D3D12CommandEncoder.destroy(@alignCast(@ptrCast(command_encoder)));
}

pub const D3D12CommandEncoder = struct {
    allocator: std.mem.Allocator,
    device: *D3D12Device,
    command_buffer: ?*D3D12CommandBuffer = null,
    barrier_enforcer: D3D12BarrierEnforcer = .{},

    pub fn create(allocator: std.mem.Allocator, device: *D3D12Device, desc: *const gpu.CommandEncoder.Descriptor) gpu.CommandEncoder.Error!*D3D12CommandEncoder {
        const command_buffer = D3D12CommandBuffer.create(allocator, device) catch
            return gpu.CommandEncoder.Error.CommandEncoderFailedToCreate;

        const self = allocator.create(
            D3D12CommandEncoder,
        ) catch return gpu.CommandEncoder.Error.CommandEncoderFailedToCreate;
        self.* = .{
            .allocator = allocator,
            .device = device,
            .command_buffer = command_buffer,
        };

        self.barrier_enforcer.init(allocator, device);

        if (desc.label) |name| {
            self.setLabel(name);
        }

        return self;
    }

    pub fn destroy(self: *D3D12CommandEncoder) void {
        if (self.command_buffer) |cb| cb.destroy();

        self.barrier_enforcer.deinit();
        self.allocator.destroy(self);
    }

    // pub fn beginComputePass(self: *D3D12CommandEncoder, desc: *const gpu.ComputePassDescriptor) gpu.Compute

    pub fn beginRenderPass(self: *D3D12CommandEncoder, allocator: std.mem.Allocator, desc: *const gpu.RenderPass.Descriptor) !*D3D12RenderPassEncoder {
        self.barrier_enforcer.endPass() catch return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToEnd;
        return D3D12RenderPassEncoder.create(allocator, self, desc);
    }

    pub fn copyBufferToBuffer(
        self: *D3D12CommandEncoder,
        src: *D3D12Buffer,
        src_offset: u64,
        dst: *D3D12Buffer,
        dst_offset: u64,
        size: u64,
    ) !void {
        const command_list = self.command_buffer.?.command_list.?;

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
        const command_list = self.command_buffer.?.command_list.?;
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
        const command_list = self.command_buffer.?.command_list;
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
        const command_list = self.command_buffer.?.command_list.?;

        self.barrier_enforcer.endPass() catch return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;
        self.barrier_enforcer.flush(command_list);

        const hr_close = command_list.ID3D12GraphicsCommandList_Close();
        if (!d3dcommon.checkHResult(hr_close)) return gpu.CommandBuffer.Error.CommandBufferFailedToCreate;

        const ret = self.command_buffer.?;
        if (desc.label) |name| {
            ret.setLabel(name);
        }

        self.command_buffer = null;
        return ret;
    }

    pub fn writeBuffer(
        self: *D3D12CommandEncoder,
        buffer: *D3D12Buffer,
        offset: u64,
        data: []const u8,
    ) !void {
        const command_list = self.command_buffer.?.command_list.?;

        const stream = try self.command_buffer.?.upload(data.len);
        @memcpy(stream.map[0..data.len], data);

        try self.barrier_enforcer.transition(&buffer.buffer, .COPY_DEST);
        self.barrier_enforcer.flush(command_list);

        command_list.ID3D12GraphicsCommandList_CopyBufferRegion(
            buffer.buffer.resource,
            offset,
            stream.resource,
            stream.offset,
            data.len,
        );
    }

    pub fn writeTexture(
        self: *D3D12CommandEncoder,
        destination: *const gpu.ImageCopyTexture,
        data: []const u8,
        data_layout: *const gpu.Texture.DataLayout,
        write_size_raw: *const gpu.Extent3D,
    ) !void {
        const command_list = self.command_buffer.?.command_list.?;
        const destination_texture: *D3D12Texture = @ptrCast(@alignCast(destination.texture));

        const stream = try self.command_buffer.?.upload(data.len);
        @memcpy(stream.map[0..data.len], data);

        try self.barrier_enforcer.transition(&destination_texture.resource.?, .COPY_DEST);
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
                .pResource = destination_texture.resource.?.resource,
                .Type = .SUBRESOURCE_INDEX,
                .Anonymous = .{
                    .SubresourceIndex = destination_subresource_index,
                },
            },
            destination_origin.x,
            destination_origin.y,
            destination_origin.z,
            &.{
                .pResource = stream.resource.?,
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

    pub fn setLabel(self: *D3D12CommandEncoder, name: []const u8) void {
        self.command_buffer.?.setLabel(name);
    }
};

pub const D3D12BarrierEnforcer = struct {
    device: *D3D12Device = undefined,

    arena_set: std.heap.ArenaAllocator = undefined,
    allocator_set: std.mem.Allocator = undefined,

    arena_barriers: std.heap.ArenaAllocator = undefined,
    allocator_barriers: std.mem.Allocator = undefined,

    written_set: std.AutoArrayHashMapUnmanaged(*const D3D12Resource, d3d12.D3D12_RESOURCE_STATES) = .{},
    barriers: std.ArrayListUnmanaged(d3d12.D3D12_RESOURCE_BARRIER) = .{},

    pub fn init(self: *D3D12BarrierEnforcer, allocator: std.mem.Allocator, device: *D3D12Device) void {
        self.arena_set = std.heap.ArenaAllocator.init(allocator);
        self.allocator_set = self.arena_set.allocator();

        self.arena_barriers = std.heap.ArenaAllocator.init(allocator);
        self.allocator_barriers = self.arena_barriers.allocator();

        self.device = device;
    }

    pub fn deinit(self: *D3D12BarrierEnforcer) void {
        self.arena_set.deinit();
        self.arena_barriers.deinit();
    }

    pub fn transition(self: *D3D12BarrierEnforcer, resource: *const D3D12Resource, new_state: d3d12.D3D12_RESOURCE_STATES) !void {
        const old_state = self.written_set.get(resource) orelse resource.read_state;

        if (old_state == .UNORDERED_ACCESS and new_state == .UNORDERED_ACCESS) {
            try self.addUnorderedAccessBarrier(resource);
        } else if (old_state != new_state) {
            try self.written_set.put(self.allocator_set, resource, new_state);
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

    pub fn addUnorderedAccessBarrier(self: *D3D12BarrierEnforcer, resource: *const D3D12Resource) !void {
        const barrier: d3d12.D3D12_RESOURCE_BARRIER = .{
            .Type = .UAV,
            .Flags = .NONE,
            .Anonymous = .{
                .UAV = .{
                    .pResource = resource.resource,
                },
            },
        };
        try self.barriers.append(self.allocator_barriers, barrier);
    }

    pub fn addTransitionBarrier(
        self: *D3D12BarrierEnforcer,
        resource: *const D3D12Resource,
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
        try self.barriers.append(self.allocator_barriers, barrier);
    }
};

// ComputePassEncoder
// ComputePipeline
// Device
pub fn deviceCreateBindGroup(
    device: *gpu.Device,
    allocator: std.mem.Allocator,
    desc: *const gpu.BindGroup.Descriptor,
) gpu.BindGroup.Error!*gpu.BindGroup {
    return @ptrCast(try D3D12BindGroup.create(
        allocator,
        @ptrCast(
            @alignCast(device),
        ),
        desc,
    ));
}

pub fn deviceCreateBindGroupLayout(
    device: *gpu.Device,
    allocator: std.mem.Allocator,
    desc: *const gpu.BindGroupLayout.Descriptor,
) gpu.BindGroupLayout.Error!*gpu.BindGroupLayout {
    return @ptrCast(try D3D12BindGroupLayout.create(
        allocator,
        @ptrCast(@alignCast(device)),
        desc,
    ));
}

pub fn deviceCreatePipelineLayout(
    device: *gpu.Device,
    allocator: std.mem.Allocator,
    desc: *const gpu.PipelineLayout.Descriptor,
) gpu.PipelineLayout.Error!*gpu.PipelineLayout {
    return @ptrCast(try D3D12PipelineLayout.create(
        allocator,
        @ptrCast(@alignCast(device)),
        desc,
    ));
}

pub fn deviceCreateRenderPipeline(
    device: *gpu.Device,
    allocator: std.mem.Allocator,
    desc: *const gpu.RenderPipeline.Descriptor,
) gpu.RenderPipeline.Error!*gpu.RenderPipeline {
    return @ptrCast(try D3D12RenderPipeline.create(
        allocator,
        @ptrCast(@alignCast(device)),
        desc,
    ));
}

pub fn deviceCreateBuffer(
    device: *gpu.Device,
    allocator: std.mem.Allocator,
    desc: *const gpu.Buffer.Descriptor,
) gpu.Buffer.Error!*gpu.Buffer {
    return @ptrCast(try D3D12Buffer.create(
        allocator,
        @ptrCast(@alignCast(device)),
        desc,
    ));
}

pub fn deviceCreateCommandEncoder(
    device: *gpu.Device,
    allocator: std.mem.Allocator,
    desc: *const gpu.CommandEncoder.Descriptor,
) gpu.CommandEncoder.Error!*gpu.CommandEncoder {
    return @ptrCast(try D3D12CommandEncoder.create(
        allocator,
        @ptrCast(@alignCast(device)),
        desc,
    ));
}

pub fn deviceCreateSampler(
    device: *gpu.Device,
    allocator: std.mem.Allocator,
    desc: *const gpu.Sampler.Descriptor,
) gpu.Sampler.Error!*gpu.Sampler {
    return @ptrCast(try D3D12Sampler.create(
        allocator,
        @ptrCast(@alignCast(device)),
        desc,
    ));
}

pub fn deviceCreateShaderModule(
    device: *gpu.Device,
    allocator: std.mem.Allocator,
    desc: *const gpu.ShaderModule.Descriptor,
) gpu.ShaderModule.Error!*gpu.ShaderModule {
    return @ptrCast(try D3D12ShaderModule.create(
        allocator,
        @ptrCast(@alignCast(device)),
        desc,
    ));
}

pub fn deviceCreateSwapChain(
    device: *gpu.Device,
    allocator: std.mem.Allocator,
    surface: ?*gpu.Surface,
    desc: *const gpu.SwapChain.Descriptor,
) gpu.SwapChain.Error!*gpu.SwapChain {
    return @ptrCast(try D3D12SwapChain.create(
        allocator,
        @ptrCast(@alignCast(device)),
        @ptrCast(@alignCast(surface.?)),
        desc,
    ));
}

pub fn deviceCreateTexture(
    device: *gpu.Device,
    allocator: std.mem.Allocator,
    desc: *const gpu.Texture.Descriptor,
) gpu.Texture.Error!*gpu.Texture {
    return @ptrCast(try D3D12Texture.create(
        allocator,
        @ptrCast(@alignCast(device)),
        desc,
    ));
}

pub fn deviceGetQueue(device: *gpu.Device) *gpu.Queue {
    return D3D12Device.getQueue(@ptrCast(@alignCast(device)));
}

pub fn deviceDestroy(device: *gpu.Device) void {
    D3D12Device.destroy(@alignCast(@ptrCast(device)));
}

const D3D12CommandSignatures = struct {
    draw: ?*d3d12.ID3D12CommandSignature = null,
    draw_indexed: ?*d3d12.ID3D12CommandSignature = null,
    dispatch: ?*d3d12.ID3D12CommandSignature = null,
};

pub const D3D12Device = struct {
    allocator: std.mem.Allocator,
    physical_device: *D3D12PhysicalDevice,
    queue: *D3D12Queue,

    device: ?*d3d12.ID3D12Device2 = null, // PhysicalDevice
    lost_cb: ?gpu.Device.LostCallback = null,

    signatures: D3D12CommandSignatures = .{},

    heap_views: descriptor.GeneralHeap,
    heap_samplers: descriptor.GeneralHeap,

    rtv_pool: descriptor.CpuPool,
    dsv_pool: descriptor.CpuPool,
    srv_uav_pool: descriptor.CpuPool,
    sampler_pool: descriptor.CpuPool,

    command_pool: D3D12CommandPool = undefined,
    streaming_pool: D3D12StreamingPool = undefined,
    mem_allocator: D3D12Allocator = undefined,
    // mem_allocator_arena: std.heap.ArenaAllocator,

    shader_compiler: ?*D3D12ShaderCompiler = null,
    shader_arena: std.heap.ArenaAllocator = undefined,

    pub fn create(allocator: std.mem.Allocator, physical_device: *D3D12PhysicalDevice, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*D3D12Device {
        const queue = allocator.create(D3D12Queue) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer allocator.destroy(queue);

        const self = allocator.create(D3D12Device) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .physical_device = physical_device,
            .queue = queue,
            .lost_cb = desc.lost_callback,

            .heap_views = undefined,
            .heap_samplers = undefined,

            .rtv_pool = undefined,
            .dsv_pool = undefined,
            .srv_uav_pool = undefined,
            .sampler_pool = undefined,

            // .mem_allocator_arena = std.heap.ArenaAllocator.init(allocator),
        };

        const hr = d3d12.D3D12CreateDevice(
            @ptrCast(physical_device.adapter),
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

        self.queue.init(self) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer D3D12Queue.deinit(queue);

        inline for (.{
            .{
                "draw",
                .{std.mem.zeroInit(d3d12.D3D12_INDIRECT_ARGUMENT_DESC, .{
                    .Type = .DRAW,
                })},
                gpu.DrawIndirectArgs,
            },
            .{
                "draw_indexed",
                .{std.mem.zeroInit(d3d12.D3D12_INDIRECT_ARGUMENT_DESC, .{
                    .Type = .DRAW_INDEXED,
                })},
                gpu.DrawIndexedIndirectArgs,
            },
            .{
                "dispatch",
                .{std.mem.zeroInit(d3d12.D3D12_INDIRECT_ARGUMENT_DESC, .{
                    .Type = .DISPATCH,
                })},
                gpu.DispatchIndirectArgs,
            },
        }) |s| {
            const sig_name = s.@"0";
            const sig_args_desc = s.@"1";
            const sig_struct = s.@"2";

            var signature: ?*d3d12.ID3D12CommandSignature = null;
            const sig_desc = d3d12.D3D12_COMMAND_SIGNATURE_DESC{
                .ByteStride = @sizeOf(sig_struct),
                .NumArgumentDescs = sig_args_desc.len,
                .pArgumentDescs = @ptrCast(&sig_args_desc),
                .NodeMask = 0,
            };

            const sig_hr = self.device.?.ID3D12Device_CreateCommandSignature(
                &sig_desc,
                null,
                d3d12.IID_ID3D12CommandSignature,
                @ptrCast(&signature),
            );
            if (!d3dcommon.checkHResult(sig_hr)) return gpu.Device.Error.DeviceFailedToCreate;

            @field(self.signatures, sig_name) = signature;
        }

        // uses a lot of memory just to have them exist in a ID3D12DescriptorHeap
        // const max_non_sampler_bindings = 1_000_000;
        // let's use 5k for now and see how it goes
        const max_non_sampler_bindings = 5_000;
        const capacity_views: u64 = max_non_sampler_bindings;
        const capacity_samplers: u64 = 2_048;

        self.heap_views = descriptor.GeneralHeap.init(allocator, self.device, .CBV_SRV_UAV, capacity_views) catch
            return gpu.Device.Error.DeviceFailedToCreate;
        self.heap_samplers = descriptor.GeneralHeap.init(allocator, self.device, .SAMPLER, capacity_samplers) catch
            return gpu.Device.Error.DeviceFailedToCreate;

        self.rtv_pool = descriptor.CpuPool.init(allocator, self.device, .RTV);
        self.dsv_pool = descriptor.CpuPool.init(allocator, self.device, .DSV);
        self.srv_uav_pool = descriptor.CpuPool.init(allocator, self.device, .CBV_SRV_UAV);
        self.sampler_pool = descriptor.CpuPool.init(allocator, self.device, .SAMPLER);

        self.command_pool = D3D12CommandPool.init(self.allocator, self);
        self.streaming_pool = D3D12StreamingPool.create(self.allocator, self);
        self.mem_allocator.init(self.allocator, self) catch
            return gpu.Device.Error.DeviceFailedToCreate;

        // TODO: conditionally enable the shader compiler through options

        self.shader_arena = std.heap.ArenaAllocator.init(allocator);
        self.shader_compiler = D3D12ShaderCompiler.create(
            self.allocator,
            self.shader_arena.allocator(),
        ) catch
            return gpu.Device.Error.DeviceFailedToCreate;

        return self;
    }

    pub fn destroy(self: *D3D12Device) void {
        if (self.lost_cb) |cb| {
            cb(.destroyed, "device destroyed");
        }
        self.queue.waitIdle();

        if (self.shader_compiler) |sc| {
            sc.destroy();
            self.shader_arena.deinit();
        }

        self.queue.deinit();

        self.command_pool.deinit();
        self.streaming_pool.deinit();
        self.mem_allocator.deinit();
        // self.mem_allocator_arena.deinit();

        self.rtv_pool.deinit();
        self.dsv_pool.deinit();
        self.srv_uav_pool.deinit();
        self.sampler_pool.deinit();

        self.heap_views.deinit();
        self.heap_samplers.deinit();

        self.allocator.destroy(self.queue);
        d3dcommon.releaseIUnknown(d3d12.ID3D12Device2, &self.device);
        self.allocator.destroy(self);
    }

    pub fn getQueue(self: *D3D12Device) *gpu.Queue {
        return @ptrCast(@alignCast(self.queue));
    }

    // internal
    pub fn createD3dBuffer(self: *D3D12Device, usage: gpu.Buffer.UsageFlags, size: u64) !D3D12Resource {
        const resource_size = if (usage.uniform) gpu.util.alignUp(size, 256) else size;

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
        const create_desc = D3D12ResourceCreateDescriptor{
            .location = if (usage.map_write)
                .gpu_to_cpu
            else if (usage.map_read)
                .cpu_to_gpu
            else
                .gpu_only,
            .resource_desc = &resource_desc,
            .clear_value = null,
            .resource_category = .buffer,
            .initial_state = if (usage.map_write)
                .GENERIC_READ
            else if (usage.map_read)
                .COPY_DEST
            else
                read_state,
        };
        return self.mem_allocator.createResource(&create_desc) catch
            return D3D12Resource.Error.ResourceFailedToCreate;
    }
};

pub const D3D12StreamingPool = struct {
    allocator: std.mem.Allocator,
    device: *D3D12Device,
    free_buffers: std.ArrayListUnmanaged(D3D12Resource) = .{},

    pub fn create(allocator: std.mem.Allocator, device: *D3D12Device) D3D12StreamingPool {
        return .{
            .allocator = allocator,
            .device = device,
        };
    }

    pub fn deinit(self: *D3D12StreamingPool) void {
        for (self.free_buffers.items) |*resource| {
            resource.deinit();
        }
        self.free_buffers.deinit(self.allocator);
    }

    pub fn acquire(self: *D3D12StreamingPool) !D3D12Resource {
        // Create new buffer
        if (self.free_buffers.items.len == 0) {
            var resource = try self.device.createD3dBuffer(.{ .map_write = true }, upload_page_size);
            errdefer resource.deinit();

            try self.free_buffers.append(self.allocator, resource);
        }

        // Result
        return self.free_buffers.pop();
    }

    pub fn release(self: *D3D12StreamingPool, d3d_resource: D3D12Resource) void {
        self.free_buffers.append(self.allocator, d3d_resource) catch {
            @panic("failed to release streaming buffer");
        };
    }
};

pub const D3D12Resource = struct {
    pub const Error = error{
        ResourceFailedToCreate,
    };

    pool: *D3D12Allocator = undefined,
    read_state: d3d12.D3D12_RESOURCE_STATES = .COMMON,
    allocation: ?D3D12Allocator.Allocation = null,
    resource: ?*d3d12.ID3D12Resource = null,
    memory_location: D3D12MemoryLocation = .unknown,
    size: u64 = 0,

    pub fn deinit(self: *D3D12Resource) void {
        self.pool.destroyResource(self) catch @panic("failed to destroy resource");
        self.allocation = null;
        self.resource = null;
    }
};

// Instance
pub fn createInstance(alloc: std.mem.Allocator, desc: *const gpu.Instance.Descriptor) gpu.Instance.Error!*gpu.Instance {
    return @ptrCast(D3D12Instance.create(alloc, desc) catch
        return gpu.Instance.Error.InstanceFailedToCreate);
}

pub fn instanceCreateSurface(
    instance: *gpu.Instance,
    allocator: std.mem.Allocator,
    desc: *const gpu.Surface.Descriptor,
) gpu.Surface.Error!*gpu.Surface {
    return @ptrCast(try D3D12Surface.create(
        allocator,
        @ptrCast(@alignCast(instance)),
        desc,
    ));
}

pub fn instanceRequestPhysicalDevice(
    instance: *gpu.Instance,
    allocator: std.mem.Allocator,
    options: *const gpu.PhysicalDevice.Options,
) gpu.PhysicalDevice.Error!*gpu.PhysicalDevice {
    return @ptrCast(try D3D12PhysicalDevice.create(
        allocator,
        @ptrCast(@alignCast(instance)),
        options,
    ));
}

pub fn instanceDestroy(instance: *gpu.Instance) void {
    D3D12Instance.destroy(@alignCast(@ptrCast(instance)));
}

pub const D3D12Instance = struct {
    allocator: std.mem.Allocator,
    factory: ?*dxgi.IDXGIFactory6 = null,
    debug_layer: ?*d3d12.ID3D12Debug = null,
    debug: bool,
    allow_tearing: bool = false,

    pub fn create(allocator: std.mem.Allocator, desc: *const gpu.Instance.Descriptor) gpu.Instance.Error!*D3D12Instance {
        const self = allocator.create(D3D12Instance) catch return gpu.Instance.Error.InstanceFailedToCreate;
        errdefer self.destroy();
        self.* = .{
            .allocator = allocator,
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
            .G,
            &self.allow_tearing,
            @sizeOf(i32), // windows expects a 4 byte bool
        ))) {
            self.allow_tearing = false;
        }

        return self;
    }

    pub fn destroy(self: *D3D12Instance) void {
        d3dcommon.releaseIUnknown(dxgi.IDXGIFactory6, &self.factory);

        if (self.debug) self.reportLiveObjects();

        d3dcommon.releaseIUnknown(d3d12.ID3D12Debug, &self.debug_layer);
        self.allocator.destroy(self);
    }

    fn reportLiveObjects(self: *D3D12Instance) void {
        _ = self;

        var dxgi_debug: ?*dxgi.IDXGIDebug = null;
        if (winapi.zig.SUCCEEDED(dxgi.DXGIGetDebugInterface1(0, dxgi.IID_IDXGIDebug, @ptrCast(&dxgi_debug)))) {
            defer d3dcommon.releaseIUnknown(dxgi.IDXGIDebug, &dxgi_debug);
            std.log.warn("live objects!", .{});
            _ = dxgi_debug.?.IDXGIDebug_ReportLiveObjects(dxgi.DXGI_DEBUG_ALL, dxgi.DXGI_DEBUG_RLO_SUMMARY);
        }
    }
};

// PhysicalDevice
pub fn physicalDeviceCreateDevice(
    physical_device: *gpu.PhysicalDevice,
    allocator: std.mem.Allocator,
    desc: *const gpu.Device.Descriptor,
) gpu.Device.Error!*gpu.Device {
    return @ptrCast(try D3D12Device.create(
        allocator,
        @ptrCast(@alignCast(physical_device)),
        desc,
    ));
}

pub fn physicalDeviceGetProperties(physical_device: *gpu.PhysicalDevice, out_props: *gpu.PhysicalDevice.Properties) bool {
    return D3D12PhysicalDevice.getProperties(@ptrCast(@alignCast(physical_device)), out_props);
}

pub fn physicalDeviceDestroy(physical_device: *gpu.PhysicalDevice) void {
    D3D12PhysicalDevice.destroy(@alignCast(@ptrCast(physical_device)));
}

pub const D3D12PhysicalDevice = struct {
    allocator: std.mem.Allocator,
    instance: *D3D12Instance,
    adapter: ?*dxgi.IDXGIAdapter = null,
    adapter_desc: dxgi.DXGI_ADAPTER_DESC = undefined,
    properties: gpu.PhysicalDevice.Properties = undefined,

    pub fn create(allocator: std.mem.Allocator, instance: *D3D12Instance, options: *const gpu.PhysicalDevice.Options) gpu.PhysicalDevice.Error!*D3D12PhysicalDevice {
        const self = allocator.create(D3D12PhysicalDevice) catch return gpu.PhysicalDevice.Error.PhysicalDeviceFailedToCreate;
        errdefer self.destroy();
        self.* = .{
            .allocator = allocator,
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

        var scratch = ScratchSpace(4096){};
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

    pub fn destroy(self: *D3D12PhysicalDevice) void {
        self.allocator.free(self.properties.name);
        d3dcommon.releaseIUnknown(dxgi.IDXGIAdapter, &self.adapter);
        self.allocator.destroy(self);
    }

    pub fn getProperties(self: *D3D12PhysicalDevice, out_props: *gpu.PhysicalDevice.Properties) bool {
        out_props.* = self.properties;
        return true;
    }
};

// PipelineLayout
pub fn pipelineLayoutDestroy(pipeline_layout: *gpu.PipelineLayout) void {
    D3D12PipelineLayout.destroy(@alignCast(@ptrCast(pipeline_layout)));
}

pub const D3D12PipelineLayout = struct {
    pub const Function = struct {
        stage: gpu.ShaderStageFlags,
        shader_module: *gpu.ShaderModule,
        entry_point: [*:0]const u8,
    };

    allocator: std.mem.Allocator,
    root_signature: *d3d12.ID3D12RootSignature,
    group_layouts: []*D3D12BindGroupLayout,
    group_parameter_indices: std.BoundedArray(u32, gpu.Limits.max_bind_groups),

    pub fn create(allocator: std.mem.Allocator, device: *D3D12Device, desc: *const gpu.PipelineLayout.Descriptor) !*D3D12PipelineLayout {
        var hr: win32.foundation.HRESULT = undefined;

        var scratch = ScratchSpace(8192){};
        const temp_allocator = scratch.init().allocator();

        // Per Bind Group:
        // - up to 1 descriptor table for CBV/SRV/UAV
        // - up to 1 descriptor table for Sampler
        // - 1 root descriptor per dynamic resource
        // Root signature 1.1 hints not supported yet

        var group_layouts = allocator.alloc(*D3D12BindGroupLayout, (desc.bind_group_layouts).len) catch
            return gpu.PipelineLayout.Error.PipelineLayoutFailedToCreate;
        errdefer allocator.free(group_layouts);

        var group_parameter_indices =
            std.BoundedArray(u32, gpu.Limits.max_bind_groups){};

        var parameter_count: u32 = 0;
        var range_count: u32 = 0;
        for (desc.bind_group_layouts, 0..) |bgl, i| {
            const layout: *D3D12BindGroupLayout = @ptrCast(@alignCast(bgl));
            group_layouts[i] = layout;
            group_parameter_indices.appendAssumeCapacity(parameter_count);

            var general_entry_count: u32 = 0;
            var sampler_entry_count: u32 = 0;
            for (layout.entries.items) |entry| {
                if (entry.dynamic_index) |_| {
                    parameter_count += 1;
                } else if (std.meta.activeTag(entry.entry.type) == .sampler) {
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

        for (desc.bind_group_layouts, 0..) |bgl, group_index| {
            const layout: *D3D12BindGroupLayout = @ptrCast(@alignCast(bgl));

            // General Table
            {
                const entry_range_base = ranges.items.len;
                for (layout.entries.items) |entry| {
                    if (entry.dynamic_index == null and std.meta.activeTag(entry.entry.type) != .sampler) {
                        ranges.appendAssumeCapacity(.{
                            .RangeType = entry.range_type,
                            .NumDescriptors = 1,
                            .BaseShaderRegister = entry.entry.binding,
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
                    if (entry.dynamic_index == null and std.meta.activeTag(entry.entry.type) == .sampler) {
                        ranges.appendAssumeCapacity(.{
                            .RangeType = entry.range_type,
                            .NumDescriptors = 1,
                            .BaseShaderRegister = entry.entry.binding,
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
                                .ShaderRegister = entry.entry.binding,
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
            std.log.err("D3D12SerializeRootSignature failed: {s}", .{message});
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
            .allocator = allocator,
            .root_signature = root_signature.?,
            .group_layouts = group_layouts,
            .group_parameter_indices = group_parameter_indices,
        };

        if (desc.label) |label| {
            const p = label;
            layout.setLabel(p);
        }

        return layout;
    }

    pub fn destroy(self: *D3D12PipelineLayout) void {
        var root_signature: ?*d3d12.ID3D12RootSignature = self.root_signature;

        d3dcommon.releaseIUnknown(d3d12.ID3D12RootSignature, &root_signature);
        self.allocator.free(self.group_layouts);
        self.allocator.destroy(self);
    }

    pub inline fn setLabel(self: *D3D12PipelineLayout, label: []const u8) void {
        setDebugName(d3d12.ID3D12RootSignature, self.root_signature, label);
    }
};

// QuerySet
// Queue
pub fn queueSubmit(queue: *gpu.Queue, command_buffers: []const *gpu.CommandBuffer) gpu.Queue.Error!void {
    try D3D12Queue.submit(@ptrCast(@alignCast(queue)), command_buffers);
}

pub fn queueWriteBuffer(
    queue: *gpu.Queue,
    buffer: *gpu.Buffer,
    offset: u64,
    data: []const u8,
) gpu.Queue.Error!void {
    D3D12Queue.writeBuffer(
        @ptrCast(@alignCast(queue)),
        @ptrCast(@alignCast(buffer)),
        offset,
        data,
    ) catch
        return gpu.Queue.Error.QueueFailure;
}

pub fn queueWriteTexture(
    queue: *gpu.Queue,
    dst: *const gpu.ImageCopyTexture,
    data: []const u8,
    layout: *const gpu.Texture.DataLayout,
    write_size: *const gpu.Extent3D,
) gpu.Queue.Error!void {
    D3D12Queue.writeTexture(
        @ptrCast(@alignCast(queue)),
        dst,
        data,
        layout,
        write_size,
    ) catch
        return gpu.Queue.Error.QueueFailure;
}

pub fn queueWaitIdle(queue: *gpu.Queue) gpu.Queue.Error!void {
    D3D12Queue.waitIdle(@ptrCast(@alignCast(queue)));
}

pub const D3D12Queue = struct {
    device: *D3D12Device,
    command_queue: ?*d3d12.ID3D12CommandQueue = null,

    arena: std.heap.ArenaAllocator = undefined,
    allocator: std.mem.Allocator = undefined,

    fence: ?*d3d12.ID3D12Fence,
    fence_value: u64 = 0,
    fence_event: win32.foundation.HANDLE = undefined,
    current_command_encoder: ?*D3D12CommandEncoder = null,

    // Assigned to a pointer, so it doesn't need to allocate
    pub fn init(self: *D3D12Queue, device: *D3D12Device) gpu.Queue.Error!void {
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

        self.* = .{
            .device = device,
            .command_queue = command_queue,
            .fence = fence,
            .fence_event = fence_event.?,
        };
        self.arena = std.heap.ArenaAllocator.init(device.allocator);
        self.allocator = self.arena.allocator();
    }

    pub fn deinit(self: *D3D12Queue) void {
        if (self.current_command_encoder) |ce| ce.destroy();
        d3dcommon.releaseIUnknown(d3d12.ID3D12CommandQueue, &self.command_queue);
        d3dcommon.releaseIUnknown(d3d12.ID3D12Fence, &self.fence);
        _ = win32.foundation.CloseHandle(self.fence_event);

        self.arena.deinit();
    }

    pub fn submit(self: *D3D12Queue, command_buffers: []const *gpu.CommandBuffer) gpu.Queue.Error!void {
        var scratch = ScratchSpace(4096){};
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
            defer _ = self.arena.reset(.retain_capacity);
            defer ce.destroy();
            // give it back so we can clean it up
            ce.command_buffer = command_buffer;
            self.current_command_encoder = null;
            command_lists.appendAssumeCapacity(command_buffer.command_list.?);
            // TODO: .takeCommandList() ?
            command_buffer.command_list = null;
        }

        for (command_buffers) |cb| {
            const command_buffer: *D3D12CommandBuffer = @ptrCast(@alignCast(cb));
            defer command_buffer.destroy();
            command_lists.appendAssumeCapacity(command_buffer.command_list.?);
            command_buffer.command_list = null;
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

    pub fn writeBuffer(
        self: *D3D12Queue,
        buffer: *D3D12Buffer,
        offset: u64,
        data: []const u8,
    ) !void {
        const encoder = try self.getCommandEncoder();
        try encoder.writeBuffer(buffer, offset, data);
    }

    pub fn writeTexture(
        self: *D3D12Queue,
        dst: *const gpu.ImageCopyTexture,
        data: []const u8,
        layout: *const gpu.Texture.DataLayout,
        write_size: *const gpu.Extent3D,
    ) !void {
        const encoder = try self.getCommandEncoder();
        try encoder.writeTexture(
            dst,
            data,
            layout,
            write_size,
        );
    }

    // internal
    pub fn signal(self: *D3D12Queue) gpu.Queue.Error!void {
        const hr = self.command_queue.?.ID3D12CommandQueue_Signal(
            @ptrCast(self.fence),
            self.fence_value,
        );
        if (!d3dcommon.checkHResult(hr)) return gpu.Queue.Error.QueueFailedToSubmit;
    }

    pub fn waitIdle(self: *D3D12Queue) void {
        _ = self.waitUntil(self.fence_value);
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

        self.current_command_encoder = try D3D12CommandEncoder.create(
            self.allocator,
            self.device,
            &.{},
        );
        return self.current_command_encoder.?;
    }
};

pub const D3D12CommandPool = struct {
    const Error = error{
        CommandPoolResetAllocatorFailed,
        CommandPoolResetListFailed,
    };

    allocator: std.mem.Allocator,
    device: *D3D12Device,
    free_allocators: std.ArrayListUnmanaged(*d3d12.ID3D12CommandAllocator),
    free_command_lists: std.ArrayListUnmanaged(*d3d12.ID3D12GraphicsCommandList),

    pub fn init(allocator: std.mem.Allocator, device: *D3D12Device) D3D12CommandPool {
        return .{
            .allocator = allocator,
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

        self.free_allocators.deinit(self.allocator);
        self.free_command_lists.deinit(self.allocator);
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
            try self.free_allocators.append(self.allocator, command_allocator.?);
        }

        const command_allocator = self.free_allocators.pop();
        self.device.queue.waitIdle();
        const reset_hr = command_allocator.ID3D12CommandAllocator_Reset();
        if (!d3dcommon.checkHResult(reset_hr)) return Error.CommandPoolResetAllocatorFailed;
        return command_allocator;
    }

    pub fn destroyCommandAllocator(self: *D3D12CommandPool, command_allocator: *d3d12.ID3D12CommandAllocator) void {
        self.free_allocators.append(self.allocator, command_allocator) catch {
            @panic("failed to destroy command allocator");
        };
    }

    pub fn createCommandList(
        self: *D3D12CommandPool,
        command_allocator: ?*d3d12.ID3D12CommandAllocator,
    ) !*d3d12.ID3D12GraphicsCommandList {
        if (self.free_command_lists.getLastOrNull() == null) {
            std.debug.print("creating new command list\n", .{});
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
        self.free_command_lists.append(self.allocator, command_list) catch {
            @panic("failed to destroy command list");
        };
    }
};

pub const D3D12ResourceCategory = enum {
    buffer,
    rtv_dsv_texture,
    other_texture,

    pub inline fn heapUsable(self: D3D12ResourceCategory, heap: D3D12HeapCategory) bool {
        return switch (heap) {
            .all => true,
            .buffer => self == .buffer,
            .rtv_dsv_texture => self == .rtv_dsv_texture,
            .other_texture => self == .other_texture,
        };
    }
};

pub const D3D12HeapCategory = enum {
    all,
    buffer,
    rtv_dsv_texture,
    other_texture,
};

pub const D3D12MemoryLocation = enum {
    unknown,
    gpu_only,
    cpu_to_gpu,
    gpu_to_cpu,
};

pub const D3D12AllocationCreateDescriptor = struct {
    location: D3D12MemoryLocation,
    size: u64,
    alignment: u64,
    resource_category: D3D12ResourceCategory,
};

pub const D3D12ResourceCreateDescriptor = struct {
    location: D3D12MemoryLocation,
    resource_category: D3D12ResourceCategory,
    resource_desc: *const d3d12.D3D12_RESOURCE_DESC,
    clear_value: ?*const d3d12.D3D12_CLEAR_VALUE,
    initial_state: d3d12.D3D12_RESOURCE_STATES,
};

/// Stores a group of heaps
pub const D3D12Allocator = struct {
    const max_memory_groups = 9;
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    device: *D3D12Device,

    memory_groups: std.BoundedArray(MemoryGroup, max_memory_groups),
    allocation_sizes: gpu_allocator.AllocationSizes,

    /// a single heap,
    /// use the gpu_allocator field to allocate chunks of memory
    pub const MemoryHeap = struct {
        index: usize,
        heap: *d3d12.ID3D12Heap,
        size: u64,
        gpu_allocator: gpu_allocator.Allocator,

        pub fn init(
            group: *MemoryGroup,
            index: usize,
            size: u64,
            dedicated: bool,
        ) gpu_allocator.Error!MemoryHeap {
            const heap = blk: {
                var desc = d3d12.D3D12_HEAP_DESC{
                    .SizeInBytes = size,
                    .Properties = group.heap_properties,
                    .Alignment = @intCast(d3d12.D3D12_DEFAULT_MSAA_RESOURCE_PLACEMENT_ALIGNMENT),
                    .Flags = d3d12.D3D12_HEAP_FLAG_NONE,
                };
                desc.Flags = switch (group.heap_category) {
                    .all => .NONE,
                    .buffer => .ALLOW_ONLY_BUFFERS,
                    .rtv_dsv_texture => .ALLOW_ONLY_RT_DS_TEXTURES,
                    .other_texture => .ALLOW_ONLY_NON_RT_DS_TEXTURES,
                };

                var heap: ?*d3d12.ID3D12Heap = null;
                const hr = group.owning_pool.device.device.?.ID3D12Device_CreateHeap(
                    &desc,
                    d3d12.IID_ID3D12Heap,
                    @ptrCast(&heap),
                );
                if (hr == win32.foundation.E_OUTOFMEMORY) return gpu_allocator.Error.OutOfMemory;
                if (!d3dcommon.checkHResult(hr)) return gpu_allocator.Error.Other;

                break :blk heap.?;
            };

            const sub_gpu_allocator = try (if (dedicated)
                gpu_allocator.Allocator.initDedicatedBlockAllocator(size)
            else
                gpu_allocator.Allocator.initOffsetAllocator(group.owning_pool.allocator, @intCast(size), null));

            return MemoryHeap{
                .index = index,
                .heap = heap,
                .size = size,
                .gpu_allocator = sub_gpu_allocator,
            };
        }

        pub fn deinit(self: *MemoryHeap) void {
            var proxy: ?*d3d12.ID3D12Heap = self.heap;
            d3dcommon.releaseIUnknown(d3d12.ID3D12Heap, @ptrCast(&proxy));
            self.gpu_allocator.deinit();
        }
    };

    /// a group of multiple heaps with a single heap type
    pub const MemoryGroup = struct {
        owning_pool: *D3D12Allocator,

        memory_location: D3D12MemoryLocation,
        heap_category: D3D12HeapCategory,
        heap_properties: d3d12.D3D12_HEAP_PROPERTIES,

        heaps: std.ArrayListUnmanaged(?MemoryHeap),

        pub const GroupAllocation = struct {
            allocation: gpu_allocator.Allocation,
            heap: *MemoryHeap,
            size: u64,
        };

        pub fn init(
            owner: *D3D12Allocator,
            memory_location: D3D12MemoryLocation,
            category: D3D12HeapCategory,
            properties: d3d12.D3D12_HEAP_PROPERTIES,
        ) MemoryGroup {
            return .{
                .owning_pool = owner,
                .memory_location = memory_location,
                .heap_category = category,
                .heap_properties = properties,
                .heaps = .{},
            };
        }

        pub fn deinit(self: *MemoryGroup) void {
            for (self.heaps.items) |*heap| {
                if (heap.*) |*h| h.deinit();
            }
            if (self.heaps.capacity > 0)
                self.heaps.deinit(self.owning_pool.allocator);
        }

        pub fn allocate(self: *MemoryGroup, size: u64) gpu_allocator.Error!GroupAllocation {
            const memblock_size: u64 = if (self.heap_properties.Type == .DEFAULT)
                self.owning_pool.allocation_sizes.device_memblock_size
            else
                self.owning_pool.allocation_sizes.host_memblock_size;
            if (size > memblock_size) {
                return self.allocateDedicated(size);
            }

            var empty_heap_index: ?usize = null;
            for (self.heaps.items, 0..) |*heap, index| {
                if (heap.*) |*h| {
                    const allocation = h.gpu_allocator.allocate(@intCast(size)) catch |err| switch (err) {
                        gpu_allocator.Error.OutOfMemory => continue,
                        else => return err,
                    };
                    return GroupAllocation{
                        .allocation = allocation,
                        .heap = h,
                        .size = size,
                    };
                } else if (empty_heap_index == null) {
                    empty_heap_index = index;
                }
            }

            // couldn't allocate, use the empty heap if we got one
            const heap = try self.addHeap(memblock_size, false, empty_heap_index);
            const allocation = try heap.gpu_allocator.allocate(@intCast(size));
            return GroupAllocation{
                .allocation = allocation,
                .heap = heap,
                .size = size,
            };
        }

        fn allocateDedicated(self: *MemoryGroup, size: u64) gpu_allocator.Error!GroupAllocation {
            const memory_block = try self.addHeap(size, true, blk: {
                for (self.heaps.items, 0..) |heap, index| {
                    if (heap == null) break :blk index;
                }
                break :blk null;
            });
            const allocation = try memory_block.gpu_allocator.allocate(@intCast(size));
            return GroupAllocation{
                .allocation = allocation,
                .heap = memory_block,
                .size = size,
            };
        }

        pub fn free(self: *MemoryGroup, allocation: GroupAllocation) gpu_allocator.Error!void {
            const heap = allocation.heap;
            try heap.gpu_allocator.free(allocation.allocation);

            // keep at least one all times to prevent erratic allocations and deallocations
            if (heap.gpu_allocator.isEmpty() and heap.index != 0) {
                const index = heap.index;
                heap.deinit();
                self.heaps.items[index] = null;
            }
        }

        fn addHeap(self: *MemoryGroup, size: u64, dedicated: bool, replace: ?usize) gpu_allocator.Error!*MemoryHeap {
            const heap_index: usize = blk: {
                if (replace) |index| {
                    if (self.heaps.items[index]) |*heap| {
                        heap.deinit();
                    }
                    self.heaps.items[index] = null;
                    break :blk index;
                } else {
                    _ = try self.heaps.addOne(self.owning_pool.allocator);
                    break :blk self.heaps.items.len - 1;
                }
                unreachable;
            };
            errdefer _ = self.heaps.popOrNull();

            self.heaps.items[heap_index] = try MemoryHeap.init(
                self,
                heap_index,
                size,
                dedicated,
            );
            return &(self.heaps.items[heap_index].?);
        }
    };

    pub const Allocation = struct {
        allocation: gpu_allocator.Allocation,
        heap: *MemoryHeap,
        size: u64,
        group: *MemoryGroup,
    };

    pub fn init(self: *D3D12Allocator, allocator: std.mem.Allocator, device: *D3D12Device) !void {
        const HeapType = struct {
            location: D3D12MemoryLocation,
            properties: d3d12.D3D12_HEAP_PROPERTIES,
        };
        const heap_types = [_]HeapType{ .{
            .location = .gpu_only,
            .properties = d3d12.D3D12_HEAP_PROPERTIES{
                .Type = .DEFAULT,
                .CPUPageProperty = .UNKNOWN,
                .MemoryPoolPreference = .UNKNOWN,
                .CreationNodeMask = 0,
                .VisibleNodeMask = 0,
            },
        }, .{
            .location = .cpu_to_gpu,
            .properties = d3d12.D3D12_HEAP_PROPERTIES{
                .Type = .CUSTOM,
                .CPUPageProperty = .WRITE_COMBINE,
                .MemoryPoolPreference = .L0,
                .CreationNodeMask = 0,
                .VisibleNodeMask = 0,
            },
        }, .{
            .location = .gpu_to_cpu,
            .properties = d3d12.D3D12_HEAP_PROPERTIES{
                .Type = .CUSTOM,
                .CPUPageProperty = .WRITE_BACK,
                .MemoryPoolPreference = .L0,
                .CreationNodeMask = 0,
                .VisibleNodeMask = 0,
            },
        } };

        self.arena = std.heap.ArenaAllocator.init(allocator);
        self.allocator = self.arena.allocator();
        self.device = device;
        self.memory_groups = std.BoundedArray(MemoryGroup, max_memory_groups).init(0) catch unreachable;
        self.allocation_sizes = .{};

        var options: d3d12.D3D12_FEATURE_DATA_D3D12_OPTIONS = undefined;
        const hr = device.device.?.ID3D12Device_CheckFeatureSupport(
            .D3D12_OPTIONS,
            @ptrCast(&options),
            @sizeOf(d3d12.D3D12_FEATURE_DATA_D3D12_OPTIONS),
        );
        if (!d3dcommon.checkHResult(hr)) return gpu_allocator.Error.Other;

        const tier_one_heap = options.ResourceHeapTier == .@"1";

        self.memory_groups = std.BoundedArray(MemoryGroup, max_memory_groups).init(0) catch unreachable;
        inline for (heap_types) |heap_type| {
            if (tier_one_heap) {
                self.memory_groups.appendAssumeCapacity(MemoryGroup.init(
                    self,
                    heap_type.location,
                    .buffer,
                    heap_type.properties,
                ));
                self.memory_groups.appendAssumeCapacity(MemoryGroup.init(
                    self,
                    heap_type.location,
                    .rtv_dsv_texture,
                    heap_type.properties,
                ));
                self.memory_groups.appendAssumeCapacity(MemoryGroup.init(
                    self,
                    heap_type.location,
                    .other_texture,
                    heap_type.properties,
                ));
            } else {
                self.memory_groups.appendAssumeCapacity(MemoryGroup.init(
                    self,
                    heap_type.location,
                    .all,
                    heap_type.properties,
                ));
            }
        }
    }

    pub fn deinit(self: *D3D12Allocator) void {
        for (self.memory_groups.slice()) |*group| {
            group.deinit();
        }
        self.arena.deinit();
    }

    pub fn reportMemoryLeaks(self: *const D3D12Allocator) void {
        std.debug.print("memory leaks: \n", .{});
        var total_blocks: u64 = 0;
        for (self.memory_groups.constSlice(), 0..) |mem_group, mem_group_index| {
            std.debug.print("   memory group {} ({s}, {s}):\n", .{
                mem_group_index,
                @tagName(mem_group.heap_category),
                @tagName(mem_group.memory_location),
            });
            for (mem_group.heaps.items, 0..) |block, block_index| {
                if (block) |found_block| {
                    std.debug.print("       block {}; total size: {}; allocated: {};\n", .{
                        block_index,
                        found_block.size,
                        found_block.gpu_allocator.getAllocated(),
                    });
                    total_blocks += 1;
                }
            }
        }

        std.debug.print("total blocks: {}\n", .{total_blocks});
    }

    pub fn allocate(self: *D3D12Allocator, desc: *const D3D12AllocationCreateDescriptor) gpu_allocator.Error!Allocation {
        // TODO: handle alignment
        for (self.memory_groups.slice()) |*memory_group| {
            if (memory_group.memory_location != desc.location and desc.location != .unknown) continue;
            if (!desc.resource_category.heapUsable(memory_group.heap_category)) continue;
            const allocation = try memory_group.allocate(desc.size);
            return Allocation{
                .allocation = allocation.allocation,
                .heap = allocation.heap,
                .size = allocation.size,
                .group = memory_group,
            };
        }
        return gpu_allocator.Error.NoCompatibleMemoryFound;
    }

    pub fn free(self: *D3D12Allocator, allocation: Allocation) gpu_allocator.Error!void {
        _ = self;
        const group = allocation.group;
        try group.free(MemoryGroup.GroupAllocation{
            .allocation = allocation.allocation,
            .heap = allocation.heap,
            .size = allocation.size,
        });
    }

    pub fn createResource(self: *D3D12Allocator, desc: *const D3D12ResourceCreateDescriptor) gpu_allocator.Error!D3D12Resource {
        const allocation_desc = blk: {
            const ID3D12Device_GetResourceAllocationInfo = *const fn (
                self: *const d3d12.ID3D12Device2,
                ret: *d3d12.D3D12_RESOURCE_ALLOCATION_INFO,
                visibleMask: u32,
                numResourceDescs: u32,
                pResourceDescs: [*]const d3d12.D3D12_RESOURCE_DESC,
            ) callconv(@import("std").os.windows.WINAPI) *d3d12.D3D12_RESOURCE_ALLOCATION_INFO;
            const getResourceAllocationInfo: ID3D12Device_GetResourceAllocationInfo =
                @ptrCast(self.device.device.?.vtable.base.base.GetResourceAllocationInfo);

            var _ret_allocation_info: d3d12.D3D12_RESOURCE_ALLOCATION_INFO = undefined;
            const allocation_info = getResourceAllocationInfo(self.device.device.?, &_ret_allocation_info, 0, 1, @ptrCast(desc.resource_desc)).*;
            break :blk D3D12AllocationCreateDescriptor{
                .location = desc.location,
                .size = allocation_info.SizeInBytes,
                .alignment = allocation_info.Alignment,
                .resource_category = desc.resource_category,
            };
        };

        const allocation = try self.allocate(&allocation_desc);

        var resource: ?*d3d12.ID3D12Resource = null;
        const hr = self.device.device.?.ID3D12Device_CreatePlacedResource(
            allocation.heap.heap,
            allocation.allocation.offset,
            desc.resource_desc,
            desc.initial_state,
            desc.clear_value,
            d3d12.IID_ID3D12Resource,
            @ptrCast(&resource),
        );
        if (!d3dcommon.checkHResult(hr)) return gpu_allocator.Error.Other;

        return D3D12Resource{
            .pool = self,
            .read_state = desc.initial_state,
            .allocation = allocation,
            .resource = resource,
            .memory_location = desc.location,
            .size = allocation.size,
        };
    }

    pub fn destroyResource(self: *D3D12Allocator, resource: *D3D12Resource) gpu_allocator.Error!void {
        if (resource.allocation) |allocation| {
            try self.free(allocation);
        }
        var proxy: ?*d3d12.ID3D12Resource = resource.resource;
        d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, @ptrCast(&proxy));
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
    D3D12RenderPassEncoder.drawIndexedIndirect(
        @ptrCast(@alignCast(render_pass_encoder)),
        @ptrCast(@alignCast(indirect_buffer)),
        indirect_offset,
    );
}

pub fn renderPassEncoderDrawIndirect(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    indirect_buffer: *gpu.Buffer,
    indirect_offset: u64,
) void {
    D3D12RenderPassEncoder.drawIndirect(
        @ptrCast(@alignCast(render_pass_encoder)),
        @ptrCast(@alignCast(indirect_buffer)),
        indirect_offset,
    );
}

pub fn renderPassEncoderEnd(render_pass_encoder: *gpu.RenderPass.Encoder) gpu.RenderPass.Encoder.Error!void {
    try D3D12RenderPassEncoder.end(@ptrCast(@alignCast(render_pass_encoder)));
}

pub fn renderPassEncoderExecuteBundles(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    bundles: []const *gpu.RenderBundle,
) void {
    _ = render_pass_encoder;
    _ = bundles;

    // TODO: ExecuteBundles
}

pub fn renderPassEncoderInsertDebugMarker(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    label: []const u8,
) void {
    _ = label;
    _ = render_pass_encoder;
}

pub fn renderPassEncoderPopDebugGroup(render_pass_encoder: *gpu.RenderPass.Encoder) void {
    _ = render_pass_encoder;
}

pub fn renderPassEncoderPushDebugGroup(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    label: []const u8,
) void {
    _ = label;
    _ = render_pass_encoder;
}

pub fn renderPassEncoderSetBindGroup(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    index: u32,
    bind_group: *gpu.BindGroup,
    dynamic_offsets: []const u32,
) void {
    D3D12RenderPassEncoder.setBindGroup(
        @ptrCast(@alignCast(render_pass_encoder)),
        index,
        @ptrCast(@alignCast(bind_group)),
        dynamic_offsets,
    );
}

pub fn renderPassEncoderSetBlendConstant(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    colour: [4]f32,
) void {
    _ = render_pass_encoder;
    _ = colour;

    // TODO: SetBlendConstant
    // D3D12RenderPassEncoder.setBlendConstant(
    //     @ptrCast(@alignCast(render_pass_encoder)),
    //     colour,
    // );
}

pub fn renderPassEncoderSetIndexBuffer(
    render_pass_encoder: *gpu.RenderPass.Encoder,
    buffer: *gpu.Buffer,
    format: gpu.IndexFormat,
    offset: u64,
    size: u64,
) gpu.RenderPass.Encoder.Error!void {
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

    // TODO: WriteTimestamp
}

pub fn renderPassEncoderDestroy(render_pass_encoder: *gpu.RenderPass.Encoder) void {
    D3D12RenderPassEncoder.destroy(@alignCast(@ptrCast(render_pass_encoder)));
}

pub const D3D12RenderPassEncoder = struct {
    allocator: std.mem.Allocator,
    device: *D3D12Device,
    command_list: ?*d3d12.ID3D12GraphicsCommandList = null,
    barrier_enforcer: *D3D12BarrierEnforcer,
    colour_attachments: std.BoundedArray(gpu.RenderPass.ColourAttachment, gpu.Limits.max_colour_attachments) = .{},
    depth_attachment: ?gpu.RenderPass.DepthStencilAttachment,
    group_parameter_indices: []u32 = undefined,
    vertex_apply_count: u32 = 0,
    vertex_buffer_views: [gpu.Limits.max_vertex_buffers]d3d12.D3D12_VERTEX_BUFFER_VIEW,
    vertex_strides: []u32 = undefined,

    rtv_allocations: std.BoundedArray(descriptor.Handle, gpu.Limits.max_colour_attachments),
    dsv_allocation: ?descriptor.Handle = null,

    label: ?[]const u8 = null,

    pub fn create(allocator: std.mem.Allocator, command_encoder: *D3D12CommandEncoder, desc: *const gpu.RenderPass.Descriptor) !*D3D12RenderPassEncoder {
        const command_list = command_encoder.command_buffer.?.command_list.?;
        const device = command_encoder.device;

        var width: u32 = 0;
        var height: u32 = 0;
        var colour_attachments: std.BoundedArray(
            gpu.RenderPass.ColourAttachment,
            gpu.Limits.max_colour_attachments,
        ) = .{};
        var rtv_allocations = std.BoundedArray(descriptor.Handle, gpu.Limits.max_colour_attachments)
            .init(desc.colour_attachments.len) catch unreachable;
        for (0..desc.colour_attachments.len) |index| {
            rtv_allocations.buffer[index] = (device.rtv_pool.alloc() catch
                return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToCreate);
        }

        for (desc.colour_attachments, 0..) |attach, index| {
            if (attach.view) |view_raw| {
                const view: *const D3D12TextureView = @ptrCast(@alignCast(view_raw));
                const texture = view.texture;

                command_encoder.barrier_enforcer.transition(
                    &texture.resource.?,
                    d3d12.D3D12_RESOURCE_STATE_RENDER_TARGET,
                ) catch
                    return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToCreate;

                width = view.width();
                height = view.height();
                colour_attachments.appendAssumeCapacity(attach);

                // TODO - rtvDesc()
                command_encoder.device.device.?.ID3D12Device_CreateRenderTargetView(
                    texture.resource.?.resource,
                    null,
                    rtv_allocations.buffer[index].cpu_descriptor,
                );
            } else {
                command_encoder.device.device.?.ID3D12Device_CreateRenderTargetView(
                    null,
                    &.{
                        .Format = .R8G8B8A8_UNORM,
                        .ViewDimension = .TEXTURE2D,
                        .Anonymous = .{ .Texture2D = .{ .MipSlice = 0, .PlaneSlice = 0 } },
                    },
                    rtv_allocations.buffer[index].cpu_descriptor,
                );
            }
        }

        var depth_attachment: ?gpu.RenderPass.DepthStencilAttachment = null;
        var dsv_allocation: ?descriptor.Handle = null;

        if (desc.depth_stencil_attachment) |attach| {
            const view: *const D3D12TextureView = @alignCast(@ptrCast(attach.view));
            const texture = view.texture;

            command_encoder.barrier_enforcer.transition(
                &texture.resource.?,
                d3d12.D3D12_RESOURCE_STATE_DEPTH_WRITE,
            ) catch
                return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToCreate;

            width = view.width();
            height = view.height();
            depth_attachment = attach.*;

            dsv_allocation = device.dsv_pool.alloc() catch
                return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToCreate;

            command_encoder.device.device.?.ID3D12Device_CreateDepthStencilView(
                texture.resource.?.resource,
                null,
                dsv_allocation.?.cpu_descriptor,
            );
        }

        command_encoder.barrier_enforcer.flush(command_list);

        const rtv_count: u32 = @intCast((desc.colour_attachments).len);
        command_list.ID3D12GraphicsCommandList_OMSetRenderTargets(
            rtv_count,
            if (rtv_allocations.len > 0) @ptrCast(&rtv_allocations.buffer) else null,
            TRUE,
            if (desc.depth_stencil_attachment != null) &dsv_allocation.?.cpu_descriptor else null,
        );

        for (desc.colour_attachments, 0..) |attach, index| {
            if (attach.load_op == .clear) {
                var clear_colour = [4]f32{
                    @floatCast(attach.clear_value.r),
                    @floatCast(attach.clear_value.g),
                    @floatCast(attach.clear_value.b),
                    @floatCast(attach.clear_value.a),
                };
                command_list.ID3D12GraphicsCommandList_ClearRenderTargetView(
                    rtv_allocations.buffer[index].cpu_descriptor,
                    &clear_colour,
                    0,
                    null,
                );
            }
        }

        if (desc.depth_stencil_attachment) |attach| {
            const clear_flags = d3d12.D3D12_CLEAR_FLAGS.initFlags(.{
                .DEPTH = if (attach.depth_load_op == .clear) 1 else 0,
                .STENCIL = if (attach.stencil_load_op == .clear) 1 else 0,
            });

            if (@intFromEnum(clear_flags) != 0) {
                command_list.ID3D12GraphicsCommandList_ClearDepthStencilView(
                    dsv_allocation.?.cpu_descriptor,
                    clear_flags,
                    attach.depth_clear_value,
                    @intCast(attach.stencil_clear_value),
                    0,
                    undefined,
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
        const scissor_rect = win32.foundation.RECT{
            .left = 0,
            .top = 0,
            .right = @intCast(width),
            .bottom = @intCast(height),
        };

        command_list.ID3D12GraphicsCommandList_RSSetViewports(1, @ptrCast(&viewport));
        command_list.ID3D12GraphicsCommandList_RSSetScissorRects(1, @ptrCast(&scissor_rect));

        // Result
        const encoder = allocator.create(D3D12RenderPassEncoder) catch
            return gpu.RenderPass.Encoder.Error.RenderPassEncoderFailedToCreate;
        encoder.* = .{
            .allocator = allocator,
            .device = device,
            .command_list = command_list,
            .colour_attachments = colour_attachments,
            .depth_attachment = depth_attachment,
            .barrier_enforcer = &command_encoder.barrier_enforcer,
            .vertex_buffer_views = std.mem.zeroes([gpu.Limits.max_vertex_buffers]d3d12.D3D12_VERTEX_BUFFER_VIEW),
            .label = desc.label,

            .rtv_allocations = rtv_allocations,
            .dsv_allocation = dsv_allocation,
        };

        return encoder;
    }

    pub fn destroy(self: *D3D12RenderPassEncoder) void {
        for (self.rtv_allocations.buffer[0..self.rtv_allocations.len]) |a|
            self.device.rtv_pool.free(a);
        if (self.dsv_allocation) |a|
            self.device.dsv_pool.free(a);

        self.allocator.destroy(self);
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

    pub fn drawIndexedIndirect(
        encoder: *D3D12RenderPassEncoder,
        indirect_buffer: *D3D12Buffer,
        indirect_offset: u64,
    ) void {
        const command_list = encoder.command_list.?;

        encoder.applyVertexBuffers();

        command_list.ID3D12GraphicsCommandList_ExecuteIndirect(
            encoder.device.signatures.draw_indexed.?,
            1,
            indirect_buffer.buffer.resource.?,
            indirect_offset,
            null,
            0,
        );
    }

    pub fn drawIndirect(
        encoder: *D3D12RenderPassEncoder,
        indirect_buffer: *D3D12Buffer,
        indirect_offset: u64,
    ) void {
        const command_list = encoder.command_list.?;

        encoder.applyVertexBuffers();

        command_list.ID3D12GraphicsCommandList_ExecuteIndirect(
            encoder.device.signatures.draw.?,
            1,
            indirect_buffer.buffer.resource.?,
            indirect_offset,
            null,
            0,
        );
    }

    pub fn end(encoder: *D3D12RenderPassEncoder) !void {
        const command_list = encoder.command_list.?;

        for (encoder.colour_attachments.slice()) |attach| {
            const view: *const D3D12TextureView = @ptrCast(@alignCast(attach.view.?));

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
            const view: *const D3D12TextureView = @ptrCast(@alignCast(attach.view));

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
        dynamic_offsets: []const u32,
    ) void {
        const command_list = encoder.command_list.?;

        var parameter_index = encoder.group_parameter_indices[group_index];

        if (group.view_table) |table| {
            command_list.ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(
                parameter_index,
                table.gpu,
            );
            parameter_index += 1;
        }

        if (group.sampler_table) |table| {
            command_list.ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(
                parameter_index,
                table.gpu,
            );
            parameter_index += 1;
        }

        for (dynamic_offsets, 0..) |dynamic_offset, i| {
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
        const command_list = encoder.command_list.?;

        encoder.group_parameter_indices = pipeline.layout.group_parameter_indices.slice();
        encoder.vertex_strides = pipeline.vertex_strides.slice();

        command_list.ID3D12GraphicsCommandList_SetGraphicsRootSignature(
            pipeline.layout.root_signature,
        );

        command_list.ID3D12GraphicsCommandList_SetPipelineState(
            pipeline.pipeline,
        );

        command_list.ID3D12GraphicsCommandList_IASetPrimitiveTopology(
            pipeline.topology,
        );
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

        const d3d_size: u32 = @intCast(if (size == gpu.whole_size) buffer.size - offset else size);

        var view = &encoder.vertex_buffer_views[slot];
        view.BufferLocation = d3d_resource.ID3D12Resource_GetGPUVirtualAddress() + offset;
        view.SizeInBytes = @intCast(d3d_size);
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
pub fn renderPipelineDestroy(pipeline: *gpu.RenderPipeline) void {
    D3D12RenderPipeline.destroy(@alignCast(@ptrCast(pipeline)));
}

pub const D3D12RenderPipeline = struct {
    allocator: std.mem.Allocator,
    device: *D3D12Device,
    pipeline: ?*d3d12.ID3D12PipelineState = null,
    layout: *D3D12PipelineLayout,
    topology: d3d.D3D_PRIMITIVE_TOPOLOGY,
    vertex_strides: std.BoundedArray(u32, gpu.Limits.max_vertex_buffers),

    pub fn create(allocator: std.mem.Allocator, device: *D3D12Device, desc: *const gpu.RenderPipeline.Descriptor) !*D3D12RenderPipeline {
        const self = allocator.create(D3D12RenderPipeline) catch
            return gpu.RenderPipeline.Error.RenderPipelineFailedToCreate;
        try self.init(allocator, device, desc);
        return self;
    }

    pub fn destroy(self: *D3D12RenderPipeline) void {
        self.deinit();
        self.allocator.destroy(self);
    }

    pub fn init(
        self: *D3D12RenderPipeline,
        allocator: std.mem.Allocator,
        device: *D3D12Device,
        desc: *const gpu.RenderPipeline.Descriptor,
    ) gpu.RenderPipeline.Error!void {
        var scratch = ScratchSpace(4096){};
        const temp_allocator = scratch.init().allocator();
        _ = temp_allocator;

        var vertex_unit: D3D12ShaderModule.Unit = .{};
        vertex_unit.init(allocator);
        defer vertex_unit.deinit();
        const vertex_module: *D3D12ShaderModule = @ptrCast(@alignCast(desc.vertex.module));
        vertex_module.compile(&vertex_unit, desc.vertex.entry_point, "vs_6_0") catch |err| {
            std.log.err("failed to compile vertex shader: {s}\nwhy: {s}", .{
                @errorName(err),
                vertex_unit.err.?,
            });

            return gpu.RenderPipeline.Error.RenderPipelineFailedToCreate;
        };

        var pixel_unit: D3D12ShaderModule.Unit = .{};
        pixel_unit.init(allocator);
        defer pixel_unit.deinit();
        if (desc.fragment) |pixel| {
            const pixel_module: *D3D12ShaderModule = @ptrCast(@alignCast(pixel.module));
            pixel_module.compile(&pixel_unit, pixel.entry_point, "ps_6_0") catch |err| {
                std.log.err("failed to compile pixel shader: {s}\nwhy: {s}", .{
                    @errorName(err),
                    pixel_unit.err.?,
                });

                return gpu.RenderPipeline.Error.RenderPipelineFailedToCreate;
            };
        }

        var input_elements = std.BoundedArray(
            d3d12.D3D12_INPUT_ELEMENT_DESC,
            gpu.Limits.max_vertex_buffers,
        ){};
        var vertex_strides = std.BoundedArray(
            u32,
            gpu.Limits.max_vertex_buffers,
        ){};
        for (desc.vertex.buffers, 0..) |buffer, slot| {
            for (buffer.attributes) |attr| {
                input_elements.appendAssumeCapacity(d3d12.D3D12_INPUT_ELEMENT_DESC{
                    // instead of using semantics, our shaders should use use custom locations
                    // LOC(0), LOC1, LOC2, etc.
                    .SemanticName = "LOC",
                    .SemanticIndex = @intCast(attr.shader_location),
                    .Format = d3dcommon.dxgiFormatForVertex(attr.format),
                    .InputSlot = @intCast(slot),
                    .AlignedByteOffset = @intCast(attr.offset),
                    .InputSlotClass = switch (buffer.step_mode) {
                        .vertex => .VERTEX_DATA,
                        .instance => .INSTANCE_DATA,
                        .vertex_buffer_not_used => undefined,
                    },
                    .InstanceDataStepRate = if (buffer.step_mode == .instance) 1 else 0,
                });
            }
            vertex_strides.appendAssumeCapacity(@intCast(buffer.array_stride));
        }

        var num_render_targets: usize = 0;
        var rtv_formats = [_]dxgi.common.DXGI_FORMAT{.UNKNOWN} ** gpu.Limits.max_colour_attachments;

        if (desc.fragment) |pixel| {
            num_render_targets = pixel.targets.len;
            for (pixel.targets, 0..) |target, i| {
                rtv_formats[i] = d3dcommon.dxgiFormatForTexture(target.format);
            }
        }

        const layout: *D3D12PipelineLayout = @ptrCast(@alignCast(desc.layout.?));

        var pipeline: ?*d3d12.ID3D12PipelineState = null;
        const pipeline_hr = device.device.?.ID3D12Device_CreateGraphicsPipelineState(
            &d3d12.D3D12_GRAPHICS_PIPELINE_STATE_DESC{
                .pRootSignature = layout.root_signature,
                .VS = vertex_unit.getD3d12ShaderBytecode(),
                .PS = pixel_unit.getD3d12ShaderBytecode(),
                .DS = no_bytecode,
                .HS = no_bytecode,
                .GS = no_bytecode,
                .StreamOutput = .{
                    .pSODeclaration = undefined,
                    .NumEntries = 0,
                    .pBufferStrides = undefined,
                    .NumStrides = 0,
                    .RasterizedStream = 0,
                },
                .BlendState = d3d12BlendDesc(desc),
                .SampleMask = desc.multisample.mask,
                .RasterizerState = d3d12RasteriserDesc(desc),
                .DepthStencilState = if (desc.depth_stencil) |ds| .{
                    .DepthEnable = if (ds.depth_compare != .always or ds.depth_write_enabled == true) TRUE else FALSE,
                    .DepthWriteMask = if (ds.depth_write_enabled == true) .ALL else .ZERO,
                    .DepthFunc = d3d12ComparisonFunc(ds.depth_compare),
                    .StencilEnable = if (stencilEnable(ds.stencil_front) or stencilEnable(ds.stencil_back)) TRUE else FALSE,
                    .StencilReadMask = @intCast(ds.stencil_read_mask & 0xff),
                    .StencilWriteMask = @intCast(ds.stencil_write_mask & 0xff),
                    .FrontFace = d3d12DepthStencilOpDesc(ds.stencil_front),
                    .BackFace = d3d12DepthStencilOpDesc(ds.stencil_back),
                } else .{
                    .DepthEnable = FALSE,
                    .DepthWriteMask = .ZERO,
                    .DepthFunc = .LESS,
                    .StencilEnable = FALSE,
                    .StencilReadMask = 0xff,
                    .StencilWriteMask = 0xff,
                    .FrontFace = d3d12DepthStencilOpDesc(null),
                    .BackFace = d3d12DepthStencilOpDesc(null),
                },
                .InputLayout = .{
                    .NumElements = @intCast(input_elements.len),
                    .pInputElementDescs = &input_elements.buffer,
                },
                .IBStripCutValue = switch (desc.primitive.strip_index_format) {
                    .undefined => .DISABLED,
                    .uint16 => .@"0xFFFF",
                    .uint32 => .@"0xFFFFFFFF",
                },
                .PrimitiveTopologyType = switch (desc.primitive.topology) {
                    .point_list => .POINT,
                    .line_list, .line_strip => .LINE,
                    .triangle_list, .triangle_strip => .TRIANGLE,
                },
                .NumRenderTargets = @intCast(num_render_targets),
                .RTVFormats = rtv_formats,
                .DSVFormat = if (desc.depth_stencil) |ds| d3dcommon.dxgiFormatForTexture(ds.format) else .UNKNOWN,
                .SampleDesc = .{
                    .Count = desc.multisample.count,
                    .Quality = 0,
                },
                .NodeMask = 0,
                .CachedPSO = .{
                    .pCachedBlob = null,
                    .CachedBlobSizeInBytes = 0,
                },
                .Flags = .NONE,
            },
            d3d12.IID_ID3D12PipelineState,
            @ptrCast(&pipeline),
        );
        if (!d3dcommon.checkHResult(pipeline_hr)) {
            return gpu.RenderPipeline.Error.RenderPipelineFailedToCreate;
        }
        errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12PipelineState, &pipeline);

        self.* = .{
            .allocator = allocator,
            .device = device,
            .pipeline = pipeline,
            .layout = layout,
            .topology = switch (desc.primitive.topology) {
                .point_list => ._PRIMITIVE_TOPOLOGY_POINTLIST,
                .line_list => ._PRIMITIVE_TOPOLOGY_LINELIST,
                .line_strip => ._PRIMITIVE_TOPOLOGY_LINESTRIP,
                .triangle_list => ._PRIMITIVE_TOPOLOGY_TRIANGLELIST,
                .triangle_strip => ._PRIMITIVE_TOPOLOGY_TRIANGLESTRIP,
            },
            .vertex_strides = vertex_strides,
        };

        if (desc.label) |label| {
            self.setLabel(label);
        }
    }

    pub fn deinit(self: *D3D12RenderPipeline) void {
        d3dcommon.releaseIUnknown(d3d12.ID3D12PipelineState, &self.pipeline);
    }

    const no_bytecode = d3d12.D3D12_SHADER_BYTECODE{
        .BytecodeLength = 0,
        .pShaderBytecode = null,
    };

    pub inline fn setLabel(self: *D3D12RenderPipeline, label: []const u8) void {
        setDebugName(d3d12.ID3D12PipelineState, self.pipeline, label);
    }
};

fn d3d12BlendDesc(desc: *const gpu.RenderPipeline.Descriptor) d3d12.D3D12_BLEND_DESC {
    var d3d12_targets = [_]d3d12.D3D12_RENDER_TARGET_BLEND_DESC{d3d12RenderTargetBlendDesc(null)} ** 8;
    if (desc.fragment) |frag| {
        for (frag.targets, 0..) |target, i| {
            d3d12_targets[i] = d3d12RenderTargetBlendDesc(target);
        }
    }

    return .{
        .AlphaToCoverageEnable = if (desc.multisample.alpha_to_coverage_enabled == true) TRUE else FALSE,
        .IndependentBlendEnable = TRUE,
        .RenderTarget = d3d12_targets,
    };
}

fn d3d12RenderTargetBlendDesc(opt_target: ?gpu.ColourTargetState) d3d12.D3D12_RENDER_TARGET_BLEND_DESC {
    var desc = d3d12.D3D12_RENDER_TARGET_BLEND_DESC{
        .BlendEnable = FALSE,
        .LogicOpEnable = FALSE,
        .SrcBlend = d3d12.D3D12_BLEND_ONE,
        .DestBlend = d3d12.D3D12_BLEND_ZERO,
        .BlendOp = d3d12.D3D12_BLEND_OP_ADD,
        .SrcBlendAlpha = d3d12.D3D12_BLEND_ONE,
        .DestBlendAlpha = d3d12.D3D12_BLEND_ZERO,
        .BlendOpAlpha = d3d12.D3D12_BLEND_OP_ADD,
        .LogicOp = d3d12.D3D12_LOGIC_OP_NOOP,
        .RenderTargetWriteMask = 0xf,
    };
    if (opt_target) |target| {
        desc.RenderTargetWriteMask = d3d12RenderTargetWriteMask(target.write_mask);
        if (target.blend) |blend| {
            desc.BlendEnable = TRUE;
            desc.SrcBlend = d3d12Blend(blend.colour.src_factor);
            desc.DestBlend = d3d12Blend(blend.colour.dst_factor);
            desc.BlendOp = d3d12BlendOp(blend.colour.operation);
            desc.SrcBlendAlpha = d3d12Blend(blend.alpha.src_factor);
            desc.DestBlendAlpha = d3d12Blend(blend.alpha.dst_factor);
            desc.BlendOpAlpha = d3d12BlendOp(blend.alpha.operation);
        }
    }

    return desc;
}

fn d3d12RenderTargetWriteMask(mask: gpu.ColourWriteMaskFlags) u8 {
    var write: u32 = 0;
    if (mask.red)
        write |= @intFromEnum(d3d12.D3D12_COLOR_WRITE_ENABLE_RED);
    if (mask.green)
        write |= @intFromEnum(d3d12.D3D12_COLOR_WRITE_ENABLE_GREEN);
    if (mask.blue)
        write |= @intFromEnum(d3d12.D3D12_COLOR_WRITE_ENABLE_BLUE);
    if (mask.alpha)
        write |= @intFromEnum(d3d12.D3D12_COLOR_WRITE_ENABLE_ALPHA);
    return @truncate(write);
}

fn d3d12Blend(factor: gpu.BlendFactor) d3d12.D3D12_BLEND {
    return switch (factor) {
        .zero => .ZERO,
        .one => .ONE,
        .src => .SRC_COLOR,
        .one_minus_src => .INV_SRC_COLOR,
        .src_alpha => .SRC_ALPHA,
        .one_minus_src_alpha => .INV_SRC_ALPHA,
        .dst => .DEST_COLOR,
        .one_minus_dst => .INV_DEST_COLOR,
        .dst_alpha => .DEST_ALPHA,
        .one_minus_dst_alpha => .INV_DEST_ALPHA,
        .src_alpha_saturated => .SRC_ALPHA_SAT,
        .constant => .BLEND_FACTOR,
        .one_minus_constant => .INV_BLEND_FACTOR,
        .src1 => .SRC1_COLOR,
        .one_minus_src1 => .INV_SRC1_COLOR,
        .src1_alpha => .SRC1_ALPHA,
        .one_minus_src1_alpha => .INV_SRC1_ALPHA,
    };
}

fn d3d12BlendOp(op: gpu.BlendOperation) d3d12.D3D12_BLEND_OP {
    return switch (op) {
        .add => .ADD,
        .subtract => .SUBTRACT,
        .reverse_subtract => .REV_SUBTRACT,
        .min => .MIN,
        .max => .MAX,
    };
}

fn d3d12RasteriserDesc(desc: *const gpu.RenderPipeline.Descriptor) d3d12.D3D12_RASTERIZER_DESC {
    return .{
        .FillMode = d3d12.D3D12_FILL_MODE_SOLID,
        .CullMode = switch (desc.primitive.cull_mode) {
            .none => .NONE,
            .front => .FRONT,
            .back => .BACK,
        },
        .FrontCounterClockwise = switch (desc.primitive.front_face) {
            .ccw => TRUE,
            .cw => FALSE,
        },
        .DepthBias = if (desc.depth_stencil) |ds| ds.depth_bias else 0,
        .DepthBiasClamp = if (desc.depth_stencil) |ds| ds.depth_bias_clamp else 0.0,
        .SlopeScaledDepthBias = if (desc.depth_stencil) |ds| ds.depth_bias_slope_scale else 0.0,
        .DepthClipEnable = if (desc.primitive.unclipped_depth == false) TRUE else FALSE,
        .MultisampleEnable = if (desc.multisample.count > 1) TRUE else FALSE,
        .AntialiasedLineEnable = FALSE,
        .ForcedSampleCount = 0,
        .ConservativeRaster = .FF,
    };
}

fn stencilEnable(stencil: gpu.StencilFaceState) bool {
    return stencil.compare != .always or
        stencil.fail_op != .keep or
        stencil.depth_fail_op != .keep or
        stencil.pass_op != .keep;
}

fn d3d12DepthStencilOpDesc(opt_stencil: ?gpu.StencilFaceState) d3d12.D3D12_DEPTH_STENCILOP_DESC {
    return if (opt_stencil) |stencil| .{
        .StencilFailOp = d3d12StencilOp(stencil.fail_op),
        .StencilDepthFailOp = d3d12StencilOp(stencil.depth_fail_op),
        .StencilPassOp = d3d12StencilOp(stencil.pass_op),
        .StencilFunc = d3d12ComparisonFunc(stencil.compare),
    } else .{
        .StencilFailOp = .KEEP,
        .StencilDepthFailOp = .KEEP,
        .StencilPassOp = .KEEP,
        .StencilFunc = .ALWAYS,
    };
}

fn d3d12StencilOp(op: gpu.StencilOperation) d3d12.D3D12_STENCIL_OP {
    return switch (op) {
        .keep => .KEEP,
        .zero => .ZERO,
        .replace => .REPLACE,
        .invert => .INVERT,
        .increment_clamp => .INCR_SAT,
        .decrement_clamp => .DECR_SAT,
        .increment_wrap => .INCR,
        .decrement_wrap => .DECR,
    };
}

// Sampler
pub fn samplerDestroy(sampler: *gpu.Sampler) void {
    D3D12Sampler.destroy(@alignCast(@ptrCast(sampler)));
}

pub const D3D12Sampler = struct {
    allocator: std.mem.Allocator,
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

    pub fn create(allocator: std.mem.Allocator, device: *D3D12Device, desc: *const gpu.Sampler.Descriptor) gpu.Sampler.Error!*D3D12Sampler {
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
            .allocator = allocator,
            .desc = d3d_desc,
        };
        return self;
    }

    pub fn destroy(self: *D3D12Sampler) void {
        self.allocator.destroy(self);
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
pub fn shaderModuleDestroy(module: *gpu.ShaderModule) void {
    D3D12ShaderModule.destroy(@alignCast(@ptrCast(module)));
}

pub const D3D12ShaderModule = struct {
    allocator: std.mem.Allocator,
    device: *D3D12Device,
    code: []const u8,

    pub const Unit = struct {
        allocator: std.mem.Allocator = undefined,
        err: ?[]const u8 = null,
        bytecode: ?[]const u8 = null,

        pub fn init(
            self: *Unit,
            allocator: std.mem.Allocator,
        ) void {
            self.* = .{
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Unit) void {
            if (self.err) |err| self.allocator.free(err);
            if (self.bytecode) |bytecode| self.allocator.free(bytecode);
        }

        pub fn getD3d12ShaderBytecode(self: *Unit) d3d12.D3D12_SHADER_BYTECODE {
            return if (self.bytecode) |bc| .{
                .pShaderBytecode = @ptrCast(bc),
                .BytecodeLength = @intCast(bc.len),
            } else .{
                .pShaderBytecode = null,
                .BytecodeLength = 0,
            };
        }
    };

    pub fn create(
        allocator: std.mem.Allocator,
        device: *D3D12Device,
        desc: *const gpu.ShaderModule.Descriptor,
    ) gpu.ShaderModule.Error!*D3D12ShaderModule {
        if (desc.source_type != .hlsl) return gpu.ShaderModule.Error.ShaderModuleUnsupportedSource;
        const self = allocator.create(D3D12ShaderModule) catch
            return gpu.ShaderModule.Error.ShaderModuleFailedToCreate;
        self.* = .{
            .allocator = allocator,
            .device = device,
            .code = desc.code,
        };
        return self;
    }

    pub fn destroy(self: *D3D12ShaderModule) void {
        self.allocator.destroy(self);
    }

    // internal
    pub fn compile(self: *D3D12ShaderModule, unit: *Unit, entry: []const u8, target: []const u8) !void {
        const compile_result = try self.device.shader_compiler.?.compile(&D3D12ShaderCompiler.Options{
            .entry = entry,
            .target = target,
            .hlsl = self.code,
        });
        defer {
            var proxy: ?*dxc.IDxcResult = null;
            d3dcommon.releaseIUnknown(dxc.IDxcResult, &proxy);
        }

        var errors: ?*dxc.IDxcBlobUtf8 = null;
        const hr = compile_result.IDxcResult_GetOutput(
            dxc.DXC_OUT_KIND.ERRORS,
            dxc.IID_IDxcBlobUtf8,
            @ptrCast(&errors),
            null,
        );
        if (!d3dcommon.checkHResult(hr)) return gpu.ShaderModule.Error.ShaderModuleFailedToCompile;

        if (errors) |errs| {
            defer d3dcommon.releaseIUnknown(dxc.IDxcBlobUtf8, &errors);
            const error_len = errs.IDxcBlobUtf8_GetStringLength();
            if (error_len > 0) {
                unit.err = try unit.allocator.dupe(u8, @ptrCast(errs.IDxcBlobUtf8_GetStringPointer().?[0..error_len]));
                return gpu.ShaderModule.Error.ShaderModuleFailedToCompile;
            }
        }

        var bytecode: ?*dxc.IDxcBlob = null;
        const bytecode_hr = compile_result.IDxcResult_GetOutput(
            dxc.DXC_OUT_KIND.OBJECT,
            dxc.IID_IDxcBlob,
            @ptrCast(&bytecode),
            null,
        );
        if (!d3dcommon.checkHResult(bytecode_hr)) return gpu.ShaderModule.Error.ShaderModuleFailedToCompile;

        if (bytecode) |bc| {
            defer d3dcommon.releaseIUnknown(dxc.IDxcBlob, &bytecode);

            const bytecode_len = bc.IDxcBlob_GetBufferSize();
            if (bytecode_len > 0) {
                unit.bytecode = try unit.allocator.dupe(u8, @as(
                    [*]u8,
                    @ptrCast(bc.IDxcBlob_GetBufferPointer().?),
                )[0..bytecode_len]);
            }
        }
    }
};

pub const D3D12ShaderCompiler = struct {
    allocator: std.mem.Allocator,
    lib: ?std.DynLib = null,
    createInstance: ?dxc.DxcCreateInstanceProc = null,

    compiler: ?*dxc.IDxcCompiler3 = null,
    utils: ?*dxc.IDxcUtils = null,
    com_allocator: ?*winappimpl.ComAllocator = null,

    pub fn create(allocator: std.mem.Allocator, child_allocator: std.mem.Allocator) !*D3D12ShaderCompiler {
        const self = try allocator.create(D3D12ShaderCompiler);
        try self.init(allocator, child_allocator);
        return self;
    }

    pub fn destroy(self: *D3D12ShaderCompiler) void {
        self.deinit();
        self.allocator.destroy(self);
    }

    pub fn init(self: *D3D12ShaderCompiler, allocator: std.mem.Allocator, child_allocator: std.mem.Allocator) !void {
        self.* = .{
            .allocator = allocator,
        };

        if (self.com_allocator == null) {
            self.com_allocator = try winappimpl.ComAllocator.create(allocator, child_allocator);
        }

        if (self.lib == null) {
            self.lib = std.DynLib.open("dxcompiler.dll") catch {
                @panic("failed to load dxcompiler.dll");
            };
            self.createInstance = self.lib.?.lookup(
                dxc.DxcCreateInstanceProc,
                "DxcCreateInstance",
            ).?;
        }

        if (self.utils == null) {
            const hr = self.createInstance.?(
                // self.com_allocator.?.getCom(),
                &dxc.CLSID_DxcLibrary,
                dxc.IID_IDxcUtils,
                @ptrCast(&self.utils),
            );
            if (!d3dcommon.checkHResult(hr)) return error.FailedToCreateShaderCompiler;
        }

        if (self.compiler == null) {
            const hr = self.createInstance.?(
                // self.com_allocator.?.getCom(),
                &dxc.CLSID_DxcCompiler,
                dxc.IID_IDxcCompiler3,
                @ptrCast(&self.compiler),
            );
            if (!d3dcommon.checkHResult(hr)) return error.FailedToCreateShaderCompiler;
        }
    }

    pub fn deinit(self: *D3D12ShaderCompiler) void {
        d3dcommon.releaseIUnknown(dxc.IDxcCompiler3, &self.compiler);
        if (self.compiler != null) std.log.warn("IDxcCompiler3 should have been destroyed", .{});

        d3dcommon.releaseIUnknown(dxc.IDxcUtils, &self.utils);
        if (self.utils != null) std.log.warn("IDxcUtils should have been destroyed", .{});

        if (self.com_allocator) |ca| {
            const count = ca.deref();
            if (count != 0) std.log.warn("ComAllocator should have been destroyed", .{});
            self.com_allocator = null;
        }

        if (self.lib) |*lib| {
            lib.close();
            self.lib = null;
        }
    }

    pub const Options = struct {
        entry: []const u8,
        target: []const u8,
        debug: bool = true,
        defines: ?[]const []const u8 = null,
        hlsl: []const u8,
    };

    pub fn compile(self: *D3D12ShaderCompiler, options: *const Options) !*dxc.IDxcResult {
        var scratch = ScratchSpace(4096){};
        const temp_allocator = scratch.init().allocator();

        var args = std.ArrayList([]const u8).init(temp_allocator);
        defer args.deinit();

        args.append("-E") catch unreachable;
        args.append(options.entry) catch unreachable;

        args.append(
            "-T",
        ) catch unreachable;
        args.append(options.target) catch unreachable;

        args.append(dxc.DXC_ARG_WARNINGS_ARE_ERRORS) catch unreachable;
        if (options.debug) {
            args.append(dxc.DXC_ARG_DEBUG) catch unreachable;
        }

        if (options.defines) |defines| {
            for (defines) |define| {
                args.append("-D") catch unreachable;
                args.append(define) catch unreachable;
            }
        }

        var source_buffer: dxc.DxcBuffer = undefined;
        source_buffer.Ptr = @ptrCast(options.hlsl.ptr);
        source_buffer.Size = @intCast(options.hlsl.len);
        source_buffer.Encoding = @intFromEnum(dxc.DXC_CP_ACP);

        var converted_args = std.ArrayList(
            [*:0]align(1) const u16,
        ).initCapacity(
            temp_allocator,
            args.items.len,
        ) catch unreachable;

        for (args.items) |arg| {
            if (winappimpl.convertToUtf16WithAllocator(temp_allocator, arg)) |utf16|
                converted_args.append(@ptrCast(@alignCast(utf16))) catch unreachable;
        }

        var result: ?*dxc.IDxcResult = null;
        const compile_hr = self.compiler.?.IDxcCompiler3_Compile(
            &source_buffer,
            converted_args.items.ptr,
            @intCast(converted_args.items.len),
            null,
            dxc.IID_IDxcResult,
            @ptrCast(&result),
        );
        if (!d3dcommon.checkHResult(compile_hr)) return gpu.ShaderModule.Error.ShaderModuleFailedToCompile;

        return result.?;
    }
};

// Surface
pub fn surfaceDestroy(surface: *gpu.Surface) void {
    D3D12Surface.destroy(@alignCast(@ptrCast(surface)));
}

pub const D3D12Surface = struct {
    allocator: std.mem.Allocator,
    hwnd: ?win32.foundation.HWND = null,

    pub fn create(allocator: std.mem.Allocator, instance: *D3D12Instance, desc: *const gpu.Surface.Descriptor) gpu.Surface.Error!*D3D12Surface {
        _ = instance;
        const self = allocator.create(D3D12Surface) catch return gpu.Surface.Error.SurfaceFailedToCreate;
        self.* = .{
            .allocator = allocator,
            .hwnd = desc.native_handle,
        };
        return self;
    }

    pub fn destroy(self: *D3D12Surface) void {
        self.allocator.destroy(self);
    }
};

// SwapChain
pub fn swapChainGetIndex(swapchain: *gpu.SwapChain) u32 {
    return D3D12SwapChain.getCurrentIndex(@ptrCast(@alignCast(swapchain)));
}

pub fn swapChainGetCurrentTexture(
    swapchain: *gpu.SwapChain,
) *const gpu.Texture {
    return @ptrCast(@alignCast(D3D12SwapChain.getCurrentTexture(@ptrCast(@alignCast(swapchain)))));
}

pub fn swapChainGetCurrentTextureView(
    swapchain: *gpu.SwapChain,
) *const gpu.TextureView {
    return @ptrCast(@alignCast(D3D12SwapChain.getCurrentTextureView(@ptrCast(@alignCast(swapchain)))));
}

pub fn swapChainGetTextureViews(
    swapchain: *gpu.SwapChain,
    views: *[3]?*const gpu.TextureView,
) u32 {
    return D3D12SwapChain.getTextureViews(@ptrCast(@alignCast(
        swapchain,
    )), @ptrCast(
        @alignCast(views),
    ));
}

pub fn swapChainPresent(swapchain: *gpu.SwapChain) !void {
    D3D12SwapChain.present(@ptrCast(@alignCast(swapchain))) catch {};
}

pub fn swapChainResize(
    swapchain: *gpu.SwapChain,
    size: [2]u32,
) gpu.SwapChain.Error!bool {
    return D3D12SwapChain.resize(
        @ptrCast(@alignCast(swapchain)),
        size,
    );
}

pub fn swapChainDestroy(swapchain: *gpu.SwapChain) void {
    D3D12SwapChain.destroy(@alignCast(@ptrCast(swapchain)));
}

pub const D3D12SwapChain = struct {
    allocator: std.mem.Allocator,
    device: *D3D12Device,

    swapchain: ?*dxgi.IDXGISwapChain4 = null,

    buffer_count: u32,
    textures: [3]D3D12Texture = .{ undefined, undefined, undefined },
    views: [3]D3D12TextureView = .{ undefined, undefined, undefined },
    fences: [3]u64 = .{ 0, 0, 0 },

    current_index: u32 = 0,

    sync_interval: u32,
    present_flags: u32,
    resize_flags: u32,
    desc: gpu.SwapChain.Descriptor = undefined,

    pub fn create(
        allocator: std.mem.Allocator,
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
            .allocator = allocator,
            .device = device,
            .swapchain = swapchain,
            .buffer_count = buffer_count,
            .sync_interval = if (desc.present_mode == .immediate) 0 else 1,
            .present_flags = if (desc.present_mode == .immediate and device.physical_device.instance.allow_tearing)
                dxgi.DXGI_PRESENT_ALLOW_TEARING
            else
                0,
            .resize_flags = swapchain_desc.Flags,
            .desc = desc.*,
        };

        self.createRenderTargets() catch return gpu.SwapChain.Error.SwapChainFailedToCreate;

        return self;
    }

    pub fn destroy(self: *D3D12SwapChain) void {
        self.releaseRenderTargets();

        self.device.queue.waitIdle();
        d3dcommon.releaseIUnknown(dxgi.IDXGISwapChain4, &self.swapchain);
        self.allocator.destroy(self);
    }

    fn createRenderTargets(self: *D3D12SwapChain) !void {
        for (0..self.buffer_count) |index| {
            var buffer: ?*d3d12.ID3D12Resource = null;
            const buffer_hr = self.swapchain.?.IDXGISwapChain_GetBuffer(
                @intCast(index),
                d3d12.IID_ID3D12Resource,
                @ptrCast(&buffer),
            );
            if (!d3dcommon.checkHResult(buffer_hr)) return gpu.SwapChain.Error.SwapChainFailedToCreate;

            var texture = &self.textures[index];
            const view = &self.views[index];

            D3D12Texture.initSwapChain(
                self.device,
                texture,
                &self.desc,
                buffer,
            );
            try texture.createViewInPlace(view, &.{});
            self.fences[index] = 0;
        }
    }

    fn releaseRenderTargets(self: *D3D12SwapChain) void {
        self.device.queue.waitIdle();

        for (self.views[0..self.buffer_count]) |*view| {
            _ = view;

            // these views don't own the texture, so we don't need to deinit them
            // view.* = null;
        }
        for (self.textures[0..self.buffer_count]) |*texture| {
            texture.deinit();
        }
    }

    fn waitAndUpdateBackBufferIndex(self: *D3D12SwapChain) void {
        _ = self.device.queue.waitIdle();
        const index = self.swapchain.?.IDXGISwapChain3_GetCurrentBackBufferIndex();
        self.current_index = index;
    }

    pub fn getCurrentIndex(self: *D3D12SwapChain) u32 {
        self.waitAndUpdateBackBufferIndex();
        return self.current_index;
    }

    pub fn getCurrentTexture(self: *D3D12SwapChain) *const D3D12Texture {
        self.waitAndUpdateBackBufferIndex();
        return &self.textures[self.current_index];
    }

    pub fn getCurrentTextureView(self: *D3D12SwapChain) *const D3D12TextureView {
        self.waitAndUpdateBackBufferIndex();
        return &self.views[self.current_index];
    }

    pub fn getTextureViews(self: *D3D12SwapChain, views: *[3]?*const D3D12TextureView) u32 {
        self.waitAndUpdateBackBufferIndex();

        for (0..self.buffer_count) |i| {
            views.*[i] = &self.views[i];
        }

        return self.buffer_count;
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

    pub fn resize(self: *D3D12SwapChain, size: [2]u32) !bool {
        if (size[0] == self.desc.width and size[1] == self.desc.height) return false;
        self.device.queue.waitIdle();
        self.desc.width = @max(size[0], 1);
        self.desc.height = @max(size[1], 1);
        self.releaseRenderTargets();

        const resize_hr = self.swapchain.?.IDXGISwapChain_ResizeBuffers(
            self.buffer_count,
            self.desc.width,
            self.desc.height,
            .UNKNOWN,
            self.resize_flags,
        );
        if (!d3dcommon.checkHResult(resize_hr)) return gpu.SwapChain.Error.SwapChainFailedToResize;

        self.createRenderTargets() catch return gpu.SwapChain.Error.SwapChainFailedToResize;
        return true;
    }
};

// Texture
pub fn textureCreateView(
    texture: *gpu.Texture,
    allocator: std.mem.Allocator,
    desc: *const gpu.TextureView.Descriptor,
) gpu.TextureView.Error!*gpu.TextureView {
    return @ptrCast(@alignCast(try D3D12Texture.createView(
        @ptrCast(@alignCast(texture)),
        allocator,
        desc,
    )));
}

pub fn textureDestroy(texture: *gpu.Texture) void {
    D3D12Texture.destroy(@alignCast(@ptrCast(texture)));
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
    allocator: std.mem.Allocator,
    device: *D3D12Device,
    resource: ?D3D12Resource = null,
    usage: gpu.Texture.UsageFlags,
    dimension: gpu.Texture.Dimension,
    size: gpu.Extent3D,
    format: gpu.Texture.Format,
    mip_level_count: u32,
    sample_count: u32,

    pub fn create(
        allocator: std.mem.Allocator,
        device: *D3D12Device,
        desc: *const gpu.Texture.Descriptor,
    ) gpu.Texture.Error!*D3D12Texture {
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

        // Only enabled if this is a RTV/DSV/buffer
        const clear_value = d3d12.D3D12_CLEAR_VALUE{ .Format = resource_desc.Format, .Anonymous = .{
            .Color = .{ 0, 0, 0, 0 },
        } };
        const create_desc = D3D12ResourceCreateDescriptor{
            .location = .gpu_only,
            .clear_value = if (desc.format.hasDepthOrStencil() or desc.usage.render_attachment)
                &clear_value
            else
                null,
            .initial_state = read_state,
            .resource_category = .other_texture,
            .resource_desc = &resource_desc,
        };
        var resource = device.mem_allocator.createResource(&create_desc) catch
            return gpu.Texture.Error.TextureFailedToCreate;
        errdefer resource.deinit();

        const self = allocator.create(D3D12Texture) catch return gpu.Texture.Error.TextureFailedToCreate;
        self.* = .{
            .allocator = allocator,
            .device = device,
            .resource = resource,
            .usage = desc.usage,
            .dimension = desc.dimension,
            .size = desc.size,
            .format = desc.format,
            .mip_level_count = desc.mip_level_count,
            .sample_count = desc.sample_count,
        };
        return self;
    }

    pub fn initSwapChain(device: *D3D12Device, texture: *D3D12Texture, desc: *const gpu.SwapChain.Descriptor, resource: ?*d3d12.ID3D12Resource) void {
        texture.* = .{
            .allocator = undefined,
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
    }

    pub fn createView(
        texture: *const D3D12Texture,
        allocator: std.mem.Allocator,
        desc: *const gpu.TextureView.Descriptor,
    ) !*D3D12TextureView {
        return D3D12TextureView.create(allocator, texture, desc);
    }

    pub fn createViewInPlace(
        texture: *const D3D12Texture,
        view: *D3D12TextureView,
        desc: *const gpu.TextureView.Descriptor,
    ) !void {
        try view.init(texture.allocator, texture, desc);
    }

    pub fn destroy(self: *D3D12Texture) void {
        self.deinit();
        self.allocator.destroy(self);
    }

    pub fn deinit(self: *D3D12Texture) void {
        if (self.resource) |*resource| resource.deinit();
    }

    // internal
    pub fn calcSubresource(self: *const D3D12Texture, mip_level: u32, array_slice: u32) u32 {
        return mip_level + (array_slice * self.mip_level_count);
    }
};

// TextureView
pub fn textureViewDestroy(texture_view: *gpu.TextureView) void {
    D3D12TextureView.destroy(@alignCast(@ptrCast(texture_view)));
}

pub const D3D12TextureView = struct {
    allocator: std.mem.Allocator,
    texture: *const D3D12Texture,
    format: gpu.Texture.Format,
    dimension: gpu.TextureView.Dimension,
    base_mip_level: u32,
    mip_level_count: u32,
    base_array_layer: u32,
    array_layer_count: ?u32,
    aspect: gpu.Texture.Aspect,
    base_subresource: u32,

    pub fn create(allocator: std.mem.Allocator, texture: *const D3D12Texture, desc: *const gpu.TextureView.Descriptor) !*D3D12TextureView {
        const self = allocator.create(D3D12TextureView) catch return gpu.TextureView.Error.TextureViewFailedToCreate;
        try self.init(allocator, texture, desc);
        return self;
    }

    pub fn init(
        self: *D3D12TextureView,
        allocator: std.mem.Allocator,
        texture: *const D3D12Texture,
        desc: *const gpu.TextureView.Descriptor,
    ) !void {
        self.* = .{
            .allocator = allocator,
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
    }

    pub fn destroy(self: *D3D12TextureView) void {
        self.allocator.destroy(self);
    }

    // internal
    pub fn width(self: *const D3D12TextureView) u32 {
        return @max(1, self.texture.size.width >> @intCast(self.base_mip_level));
    }

    pub fn height(self: *const D3D12TextureView) u32 {
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
