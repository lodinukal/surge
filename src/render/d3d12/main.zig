const std = @import("std");
const gpu = @import("../gpu.zig");

const winapi = @import("win32");
const win32 = winapi.windows.win32;
const d3d = win32.graphics.direct3d;
const d3d12 = win32.graphics.direct3d12;
const dxgi = win32.graphics.dxgi;
const hlsl = win32.graphics.hlsl;

const TRUE = win32.foundation.TRUE;
const FALSE = win32.foundation.FALSE;

const conv = @import("conv.zig");

const winappimpl = @import("../../app/platform/windows.zig");

const d3dcommon = @import("../d3d/common.zig");

const common = @import("../../core/common.zig");

const render_target_view_heap_size: u32 = 1024;
const depth_stencil_view_heap_size: u32 = 1024;
const shader_resource_view_heap_size: u32 = 16384;
const sampler_heap_size: u32 = 1024;
const max_timer_queries: u32 = 256;

// Loading
pub const procs: gpu.procs.Procs = .{ // Heap
    .heapGetDescriptor = heapGetDescriptor,
    .heapDestroy = heapDestroy,

    // Texture
    .textureGetDescriptor = textureGetDescriptor,
    .textureGetView = textureGetView,
    .textureDestroy = textureDestroy,

    // TextureView
    .textureViewDestroy = textureViewDestroy,

    // StagingTexture
    .stagingTextureGetDescriptor = stagingTextureGetDescriptor,
    .stagingTextureDestroy = stagingTextureDestroy,

    // InputLayout
    .inputLayoutGetAttributes = inputLayoutGetAttributes,
    .inputLayoutDestroy = inputLayoutDestroy,

    // Buffer
    .bufferGetDescriptor = bufferGetDescriptor,
    .bufferDestroy = bufferDestroy,

    // Shader
    .shaderGetDescriptor = shaderGetDescriptor,
    .shaderGetBytecode = shaderGetBytecode,
    .shaderDestroy = shaderDestroy,

    // Sampler
    .samplerGetDescriptor = samplerGetDescriptor,
    .samplerDestroy = samplerDestroy,

    // Framebuffer
    .framebufferGetDescriptor = framebufferGetDescriptor,
    .framebufferGetFramebufferInfo = framebufferGetFramebufferInfo,
    .framebufferDestroy = framebufferDestroy,

    // BindingLayout
    .bindingLayoutGetDescriptor = bindingLayoutGetDescriptor,
    .bindingLayoutGetBindlessDescriptor = bindingLayoutGetBindlessDescriptor,
    .bindingLayoutDestroy = bindingLayoutDestroy,

    // BindingSet
    .bindingSetGetDescriptor = bindingSetGetDescriptor,
    .bindingSetGetLayout = bindingSetGetLayout,
    .bindingSetDestroy = bindingSetDestroy,

    // DescriptorTable
    .descriptorTableGetDescriptor = descriptorTableGetDescriptor,
    .descriptorTableGetLayout = descriptorTableGetLayout,
    .descriptorTableGetCapacity = descriptorTableGetCapacity,
    .descriptorTableDestroy = descriptorTableDestroy,

    // GraphicsPipeline
    .graphicsPipelineGetDescriptor = graphicsPipelineGetDescriptor,
    .graphicsPipelineGetFramebufferInfo = graphicsPipelineGetFramebufferInfo,
    .graphicsPipelineDestroy = graphicsPipelineDestroy,

    // ComputePipeline
    .computePipelineGetDescriptor = computePipelineGetDescriptor,
    .computePipelineDestroy = computePipelineDestroy,

    // MeshletPipeline
    .meshletPipelineGetDescriptor = meshletPipelineGetDescriptor,
    .meshletPipelineGetFramebufferInfo = meshletPipelineGetFramebufferInfo,
    .meshletPipelineDestroy = meshletPipelineDestroy,

    // EventQuery
    .eventQueryDestroy = eventQueryDestroy,

    // TimerQuery
    .timerQueryDestroy = timerQueryDestroy,

    // CommandList
    .commandListOpen = commandListOpen,
    .commandListClose = commandListClose,
    .commandListClearState = commandListClearState,
    .commandListClearTextureFloat = commandListClearTextureFloat,
    .commandListClearDepthStencilTexture = commandListClearDepthStencilTexture,
    .commandListClearTextureUint = commandListClearTextureUint,
    .commandListCopyTextureToTexture = commandListCopyTextureToTexture,
    .commandListCopyToStagingTexture = commandListCopyToStagingTexture,
    .commandListCopyStagingTextureToTexture = commandListCopyStagingTextureToTexture,
    .commandListWriteTexture = commandListWriteTexture,
    .commandListResolveTexture = commandListResolveTexture,
    .commandListWriteBuffer = commandListWriteBuffer,
    .commandListClearBufferUint = commandListClearBufferUint,
    .commandListCopyBufferToBuffer = commandListCopyBufferToBuffer,
    .commandListSetPushConstants = commandListSetPushConstants,
    .commandListSetGraphicsState = commandListSetGraphicsState,
    .commandListDraw = commandListDraw,
    .commandListDrawIndexed = commandListDrawIndexed,
    .commandListDrawIndirect = commandListDrawIndirect,
    .commandListDrawIndexedIndirect = commandListDrawIndexedIndirect,
    .commandListSetComputeState = commandListSetComputeState,
    .commandListDispatch = commandListDispatch,
    .commandListDispatchIndirect = commandListDispatchIndirect,
    .commandListSetMeshletState = commandListSetMeshletState,
    .commandListDispatchMesh = commandListDispatchMesh,
    .commandListBeginTimerQuery = commandListBeginTimerQuery,
    .commandListEndTimerQuery = commandListEndTimerQuery,
    .commandListBeginMarker = commandListBeginMarker,
    .commandListEndMarker = commandListEndMarker,
    .commandListSetEnableAutomaticBarriers = commandListSetEnableAutomaticBarriers,
    .commandListSetEnableUAVBarriersForTexture = commandListSetEnableUAVBarriersForTexture,
    .commandListSetEnableUAVBarriersForBuffer = commandListSetEnableUAVBarriersForBuffer,
    .commandListBeginTrackingTextureState = commandListBeginTrackingTextureState,
    .commandListBeginTrackingBufferState = commandListBeginTrackingBufferState,
    .commandListSetTextureState = commandListSetTextureState,
    .commandListSetBufferState = commandListSetBufferState,
    .commandListSetPermanentTextureState = commandListSetPermanentTextureState,
    .commandListSetPermanentBufferState = commandListSetPermanentBufferState,
    .commandListCommitBarriers = commandListCommitBarriers,
    .commandListGetTextureSubresourceState = commandListGetTextureSubresourceState,
    .commandListGetBufferState = commandListGetBufferState,
    .commandListGetDescriptor = commandListGetDescriptor,

    // Device
    .deviceCreateSwapChain = deviceCreateSwapChain,
    .deviceCreateHeap = deviceCreateHeap,
    .deviceCreateTexture = deviceCreateTexture,
    .deviceGetTextureMemoryRequirements = deviceGetTextureMemoryRequirements,
    .deviceBindTextureMemory = deviceBindTextureMemory,
    .deviceCreateStagingTexture = deviceCreateStagingTexture,
    .deviceMapStagingTexture = deviceMapStagingTexture,
    .deviceMapStagingTextureConst = deviceMapStagingTextureConst,
    .deviceUnmapStagingTexture = deviceUnmapStagingTexture,
    .deviceCreateBuffer = deviceCreateBuffer,
    .deviceMapBuffer = deviceMapBuffer,
    .deviceMapBufferConst = deviceMapBufferConst,
    .deviceUnmapBuffer = deviceUnmapBuffer,
    .deviceGetBufferMemoryRequirements = deviceGetBufferMemoryRequirements,
    .deviceBindBufferMemory = deviceBindBufferMemory,
    .deviceCreateShader = deviceCreateShader,
    .deviceCreateShaderSpecialisation = deviceCreateShaderSpecialisation,
    .deviceCreateShaderLibrary = deviceCreateShaderLibrary,
    .deviceCreateSampler = deviceCreateSampler,
    .deviceCreateInputLayout = deviceCreateInputLayout,
    .deviceCreateEventQuery = deviceCreateEventQuery,
    .deviceSetEventQuery = deviceSetEventQuery,
    .devicePollEventQuery = devicePollEventQuery,
    .deviceWaitEventQuery = deviceWaitEventQuery,
    .deviceResetEventQuery = deviceResetEventQuery,
    .deviceCreateTimerQuery = deviceCreateTimerQuery,
    .devicePollTimerQuery = devicePollTimerQuery,
    .deviceGetTimerQueryTime = deviceGetTimerQueryTime,
    .deviceResetTimerQuery = deviceResetTimerQuery,
    .deviceCreateFramebuffer = deviceCreateFramebuffer,
    .deviceCreateGraphicsPipeline = deviceCreateGraphicsPipeline,
    .deviceCreateComputePipeline = deviceCreateComputePipeline,
    .deviceCreateMeshletPipeline = deviceCreateMeshletPipeline,
    .deviceCreateBindingLayout = deviceCreateBindingLayout,
    .deviceCreateBindlessBindingLayout = deviceCreateBindlessBindingLayout,
    .deviceCreateBindingSet = deviceCreateBindingSet,
    .deviceCreateDescriptorTable = deviceCreateDescriptorTable,
    .deviceResizeDescriptorTable = deviceResizeDescriptorTable,
    .deviceWriteDescriptorTable = deviceWriteDescriptorTable,
    .deviceCreateCommandList = deviceCreateCommandList,
    .deviceExecuteCommandLists = deviceExecuteCommandLists,
    .deviceQueueWaitForCommandList = deviceQueueWaitForCommandList,
    .deviceWaitForIdle = deviceWaitForIdle,
    .deviceCleanGarbage = deviceCleanGarbage,
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
    // ShaderModule
    // Surface
    .surfaceDestroy = surfaceDestroy,
    // SwapChain
    // .swapChainGetCurrentTexture = swapChainGetCurrentTexture,
    // .swapChainGetCurrentTextureView = swapChainGetCurrentTextureView,
    .swapChainPresent = swapChainPresent,
    .swapChainResize = swapChainResize,
    .swapChainDestroy = swapChainDestroy,
};

export fn getProcs() *const gpu.procs.Procs {
    return &procs;
}

pub const RootSignature = opaque {};

pub const Context = struct {
    device: ?*d3d12.ID3D12Device2 = null,

    draw_indirect_signature: ?*d3d12.ID3D12CommandSignature = null,
    draw_indexed_indirect_signature: ?*d3d12.ID3D12CommandSignature = null,
    dispatch_indirect_signature: ?*d3d12.ID3D12CommandSignature = null,

    timer_query_heap: ?*d3d12.ID3D12QueryHeap = null,
    timer_query_resolve_buffer: ?*gpu.Buffer = null,

    message_callback: ?*const fn (severity: gpu.MessageSeverity, message: []const u8) void = null,

    pub fn err(self: *const Context, message: []const u8) void {
        if (self.message_callback) |f| {
            f.*(.err, message);
        }
    }

    pub fn deinit(self: *Context) void {
        d3dcommon.releaseIUnknown(d3d12.ID3D12Device2, &self.device);
        d3dcommon.releaseIUnknown(d3d12.ID3D12CommandSignature, &self.draw_indirect_signature);
        d3dcommon.releaseIUnknown(d3d12.ID3D12CommandSignature, &self.draw_indexed_indirect_signature);
        d3dcommon.releaseIUnknown(d3d12.ID3D12CommandSignature, &self.dispatch_indirect_signature);
        d3dcommon.releaseIUnknown(d3d12.ID3D12QueryHeap, &self.timer_query_heap);
        d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, &self.timer_query_resolve_buffer);
    }
};

pub fn waitForFence(fence: *d3d12.ID3D12Fence, value: u64, event: win32.foundation.HANDLE) void {
    if (fence.ID3D12Fence_GetCompletedValue() < value) {
        win32.system.threading.ResetEvent(event);
        fence.ID3D12Fence_SetEventOnCompletion(value, event);
        win32.system.threading.WaitForSingleObject(event, win32.system.threading.INFINITE);
    }
}

pub const DeviceResources = struct {
    context: *const Context,
    dxgi_format_plane_counts: [
        std.enums.directEnumArrayLen(
            dxgi.common.DXGI_FORMAT,
            72,
        )
    ]?u8 = std.enums.directEnumArrayDefault(
        dxgi.common.DXGI_FORMAT,
        ?u8,
        null,
        72,
        .{},
    ),

    rtv_heap: StaticDescriptorHeap,
    dsv_heap: StaticDescriptorHeap,
    srv_heap: StaticDescriptorHeap,
    sampler_heap: StaticDescriptorHeap,
    root_signature_cache: std.AutoArrayHashMap(usize, *RootSignature),
    timer_queries_bits: std.PackedIntArray(u1, 256) = std.PackedIntArray(u1, 256).initAllTo(0),

    pub fn init(self: *DeviceResources, context: *const Context) !void {
        self.* = .{
            .context = context,
            .rtv_heap = StaticDescriptorHeap.init(context),
            .dsv_heap = StaticDescriptorHeap.init(context),
            .srv_heap = StaticDescriptorHeap.init(context),
            .sampler_heap = StaticDescriptorHeap.init(context),
            .root_signature_cache = std.AutoArrayHashMap(usize, *RootSignature).init(allocator),
        };
    }

    pub fn deinit(self: *DeviceResources) void {
        self.rtv_heap.deinit();
        self.dsv_heap.deinit();
        self.srv_heap.deinit();
        self.sampler_heap.deinit();

        self.root_signature_cache.deinit();
    }

    pub fn getFormatPlaneCount(self: *DeviceResources, format: dxgi.common.DXGI_FORMAT) u8 {
        const count = &self.dxgi_format_plane_counts[format];
        if (count.* == 0) {
            var format_info: d3d12.D3D12_FEATURE_DATA_FORMAT_INFO = .{
                .Format = format,
                .PlaneCount = 1,
            };
            if (winapi.zig.FAILED(self.context.device.?.ID3D12Device_CheckFeatureSupport(
                .FORMAT_INFO,
                @ptrCast(&format_info),
                @sizeOf(d3d12.D3D12_FEATURE_DATA_FORMAT_INFO),
            ))) {
                count.* = 255;
            } else {
                count.* = format_info.PlaneCount;
            }
        }

        if (count.* == 255) return 0;

        return count;
    }
};

pub const DescriptorIndex = u32;
pub const DescriptorHeapType = enum {
    rtv,
    dsv,
    srv,
    sampler,
};
pub const StaticDescriptorHeap = struct {
    pub const Error = error{
        StaticDescriptorHeapFailedToCreateHeap,
        StaticDescriptorHeapFailedToCreateShaderVisibleHeap,
        StaticDescriptorHeapFailedToResize,
    };

    context: *const Context,
    heap: ?*d3d12.ID3D12DescriptorHeap = null,
    shader_visible_heap: ?*d3d12.ID3D12DescriptorHeap = null,
    heap_type: d3d12.D3D12_DESCRIPTOR_HEAP_TYPE = .CBV_SRV_UAV,
    start_cpu_handle: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE = .{ .ptr = 0 },
    start_cpu_handle_shader_visible: d3d12.D3D12_CPU_DESCRIPTOR_HANDLE = .{ .ptr = 0 },
    start_gpu_handle_shader_visible: d3d12.D3D12_GPU_DESCRIPTOR_HANDLE = .{ .ptr = 0 },
    stride: u32 = 0,
    num_descriptors: u32 = 0,
    allocated_descriptors: std.ArrayList(bool),
    search_start: DescriptorIndex = 0,
    num_allocated_descriptors: u32 = 0,
    mutex: std.Thread.Mutex = .{},

    pub fn init(context: *const Context) StaticDescriptorHeap {
        return .{
            .context = context,
            .allocated_descriptors = std.ArrayList(bool).init(allocator),
        };
    }

    pub fn deinit(self: *StaticDescriptorHeap) void {
        d3dcommon.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &self.heap);
        d3dcommon.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &self.shader_visible_heap);
        self.allocated_descriptors.deinit();
    }

    pub fn allocateResources(
        self: *StaticDescriptorHeap,
        heap_type: d3d12.D3D12_DESCRIPTOR_HEAP_TYPE,
        num_descriptors: u32,
        shader_visible: bool,
    ) Error!void {
        d3dcommon.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &self.heap);
        d3dcommon.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &self.shader_visible_heap);

        var heap_desc: d3d12.D3D12_DESCRIPTOR_HEAP_DESC = undefined;
        heap_desc.Type = heap_type;
        heap_desc.NumDescriptors = num_descriptors;
        heap_desc.Flags = .NONE;

        var hr = self.context.device.?.ID3D12Device_CreateDescriptorHeap(
            &heap_desc,
            d3d12.IID_ID3D12DescriptorHeap,
            @ptrCast(&self.heap),
        );

        if (winapi.zig.FAILED(hr)) return Error.StaticDescriptorHeapFailedToCreateHeap;

        if (shader_visible) {
            heap_desc.Flags = .SHADER_VISIBLE;

            hr = self.context.device.?.ID3D12Device_CreateDescriptorHeap(
                &heap_desc,
                d3d12.IID_ID3D12DescriptorHeap,
                @ptrCast(&self.shader_visible_heap),
            );

            if (winapi.zig.FAILED(hr)) return Error.StaticDescriptorHeapFailedToCreateShaderVisibleHeap;

            self.start_cpu_handle_shader_visible = self.shader_visible_heap.?.ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart();
            self.start_gpu_handle_shader_visible = self.shader_visible_heap.?.ID3D12DescriptorHeap_GetGPUDescriptorHandleForHeapStart();
        }

        self.num_descriptors = num_descriptors;
        self.heap_type = heap_type;
        self.start_cpu_handle = self.heap.?.ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart();
        self.stride = self.context.device.?.ID3D12Device_GetDescriptorHandleIncrementSize(heap_type);
        self.allocated_descriptors.resize(num_descriptors) catch return Error.StaticDescriptorHeapFailedToResize;
    }

    fn nextPowerOf2(in: u32) u32 {
        var v = in;
        v -= 1;
        v |= v >> 1;
        v |= v >> 2;
        v |= v >> 4;
        v |= v >> 8;
        v |= v >> 16;
        return v + 1;
    }

    pub fn grow(self: *StaticDescriptorHeap, min_required_size: u32) Error!void {
        const old_size = self.num_descriptors;
        const new_size = nextPowerOf2(min_required_size);

        const old_heap = self.heap;
        defer d3dcommon.releaseIUnknown(d3d12.ID3D12DescriptorHeap, &old_heap);

        try self.allocateResources(
            self.heap_type,
            new_size,
            self.shader_visible_heap != null,
        );

        self.context.device.?.ID3D12Device_CopyDescriptorsSimple(
            old_size,
            self.start_cpu_handle,
            old_heap.?.ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(),
            self.heap_type,
        );

        if (self.shader_visible_heap) |svh| {
            self.context.device.?.ID3D12Device_CopyDescriptorsSimple(
                old_size,
                self.start_cpu_handle_shader_visible,
                svh.?.ID3D12DescriptorHeap_GetCPUDescriptorHandleForHeapStart(),
                self.heap_type,
            );
        }

        return win32.foundation.S_OK;
    }

    pub fn allocateDescriptors(self: *StaticDescriptorHeap, count: u32) Error!DescriptorIndex {
        self.mutex.lock();
        defer self.mutex.unlock();

        var found_range = false;
        var found_index: DescriptorIndex = 0;
        var free_count: u32 = 0;

        for (self.search_start..self.num_descriptors) |index| {
            if (self.allocated_descriptors.items[index]) {
                free_count = 0;
            } else {
                free_count += 1;
            }

            if (free_count >= count) {
                found_range = true;
                found_index = index - count + 1;
                break;
            }
        }

        if (!found_range) {
            found_index = self.num_descriptors;

            try self.grow(self.num_descriptors + count);
        }

        for (found_index..(found_index + count)) |index| {
            self.allocated_descriptors.items[index] = true;
        }

        self.num_allocated_descriptors += count;
        self.search_start = found_index + count;
        return found_index;
    }

    pub fn allocateOneDescriptor(self: *StaticDescriptorHeap) Error!DescriptorIndex {
        return try self.allocateDescriptors(1);
    }

    pub fn releaseDescriptors(self: *StaticDescriptorHeap, base_index: DescriptorIndex, count: u32) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (count == 0) return;

        for (base_index..(base_index + count)) |index| {
            self.allocated_descriptors.items[index] = false;
        }

        self.num_allocated_descriptors -= count;
        if (self.search_start > base_index) self.search_start = base_index;
    }

    pub fn releaseDescriptor(self: *StaticDescriptorHeap, index: DescriptorIndex) void {
        self.releaseDescriptors(index, 1);
    }

    pub fn getCpuHandle(
        self: *const StaticDescriptorHeap,
        index: DescriptorIndex,
    ) d3d12.D3D12_CPU_DESCRIPTOR_HANDLE {
        return .{
            .ptr = self.start_cpu_handle.ptr + (index * self.stride),
        };
    }

    pub fn getCpuHandleShaderVisible(
        self: *const StaticDescriptorHeap,
        index: DescriptorIndex,
    ) d3d12.D3D12_CPU_DESCRIPTOR_HANDLE {
        return .{
            .ptr = self.start_cpu_handle_shader_visible.ptr + (index * self.stride),
        };
    }

    pub fn getGpuHandleShaderVisible(
        self: *const StaticDescriptorHeap,
        index: DescriptorIndex,
    ) d3d12.D3D12_GPU_DESCRIPTOR_HANDLE {
        return .{
            .ptr = self.start_gpu_handle_shader_visible.ptr + (index * self.stride),
        };
    }

    pub fn copyToShaderVisibleHeap(
        self: *StaticDescriptorHeap,
        index: DescriptorIndex,
        count: ?u32,
    ) void {
        self.context.device.?.ID3D12Device_CopyDescriptorsSimple(
            count orelse 1,
            self.getCpuHandleShaderVisible(index),
            self.getCpuHandle(index),
            self.heap_type,
        );
    }
};

pub fn shaderGetDescriptor(shader: *const gpu.Shader) *const gpu.Shader.Descriptor {
    return Shader.getDescriptor(@ptrCast(@alignCast(shader)));
}
pub fn shaderGetBytecode(shader: *const gpu.Shader) []const u8 {
    return Shader.getByteCode(@ptrCast(@alignCast(shader)));
}
pub fn shaderDestroy(shader: *gpu.Shader) void {
    Shader.deinit(@alignCast(@ptrCast(shader)));
}

pub const Shader = struct {
    descriptor: gpu.Shader.Descriptor,
    bytecode: std.ArrayList(u8),

    pub fn getDescriptor(self: *const Shader) *const gpu.Shader.Descriptor {
        return &self.descriptor;
    }

    pub fn getByteCode(shader: *const Shader) []const u8 {
        return shader.bytecode.items[0..shader.bytecode.len];
    }

    pub fn deinit(self: *Shader) void {
        self.bytecode.deinit();
    }
};

pub fn heapGetDescriptor(heap: *const gpu.Heap) *const gpu.Heap.Descriptor {
    return Heap.getDescriptor(@ptrCast(@alignCast(heap)));
}
pub fn heapDestroy(heap: *gpu.Heap) void {
    Heap.deinit(@alignCast(@ptrCast(heap)));
}

pub const Heap = struct {
    descriptor: gpu.Heap.Descriptor,
    heap: ?*d3d12.ID3D12Heap = null,

    pub fn getDescriptor(self: *const Heap) *const gpu.Heap.Descriptor {
        return &self.descriptor;
    }

    pub fn deinit(self: *Heap) void {
        d3dcommon.releaseIUnknown(d3d12.ID3D12Heap, &self.heap);
    }
};

pub fn textureGetDescriptor(texture: *const gpu.Texture) *const gpu.Texture.Descriptor {
    return Texture.getDescriptor(@ptrCast(@alignCast(texture)));
}

pub fn textureGetView(
    texture: *const gpu.Texture,
    desc: *const gpu.TextureView.Descriptor,
) !*gpu.TextureView {
    return @ptrCast(@alignCast(Texture.getView(texture, desc)));
}

pub fn textureDestroy(texture: *gpu.Texture) void {
    Texture.deinit(@alignCast(@ptrCast(texture)));
}

pub const Texture = struct {
    context: *const Context,
    resources: *DeviceResources,

    tracker: gpu.state_tracker.TextureStateTracker,
    descriptor: gpu.Texture.Descriptor, // const
    resource_desc: d3d12.D3D12_RESOURCE_DESC, // const
    resource: ?*d3d12.ID3D12Resource = null,
    plane_count: u8 = 1,
    heap: ?*Heap,

    pub fn init(
        context: *const Context,
        resources: *DeviceResources,
        desc: gpu.Texture.Descriptor,
        resource_desc: *const d3d12.D3D12_RESOURCE_DESC,
    ) !*Texture {
        const texture = allocator.create(Texture) catch return null;
        errdefer allocator.destroy(texture);

        texture.* = .{
            .context = context,
            .resources = resources,
            .tracker = undefined,
            .descriptor = desc,
            .resource_desc = resource_desc.*,
        };

        texture.tracker = .{
            .descriptor = &texture.descriptor,
        };

        return texture;
    }

    pub fn deinit(self: *Texture) void {
        d3dcommon.releaseIUnknown(d3d12.ID3D12Resource, &self.resource);
    }

    fn afterInit(self: *Texture) void {
        if (self.descriptor.debug_label) |dbgl| {
            var scratch = common.ScratchSpace(256){};
            const temp_allocator = scratch.init().allocator();

            self.resource.?.ID3D12Object_SetName(winappimpl.convertToUtf16WithAllocator(
                temp_allocator,
                dbgl,
            ) orelse
                "<dbgname>");
        }

        if (self.descriptor.is_uav) {
            // TODO: clear mip level uavs
            // resize the buffer
            // also make sure its destroyed
            // and fill it with the invalid descriptor index
        }

        self.plane_count = self.resources.getFormatPlaneCount(self.resource_desc.Format);
    }

    pub fn getDescriptor(self: *const Texture) *const gpu.Texture.Descriptor {
        return &self.descriptor;
    }

    pub fn getView(
        self: *const Texture,
        desc: *const gpu.TextureView.Descriptor,
    ) !*TextureView {
        return TextureView.init(self, desc);
    }
};

pub fn textureViewDestroy(texture_view: *gpu.TextureView) void {
    TextureView.deinit(@alignCast(@ptrCast(texture_view)));
}

pub const TextureView = struct {
    resources: *DeviceResources,
    d3d_descriptor: DescriptorIndex,
    descriptor: gpu.TextureView.Descriptor,
    parent: *Texture,
    source_heap: DescriptorHeapType = undefined,

    pub fn init(
        parent_texture: *Texture,
        desc: *const gpu.TextureView.Descriptor,
    ) !*TextureView {
        const resources = parent_texture.resources;

        const self = allocator.create(TextureView) catch
            return gpu.TextureView.Error.TextureViewFailedToCreate;
        errdefer allocator.destroy(self);
        self.* = .{
            .resources = resources,
            .d3d_descriptor = undefined,
            .descriptor = desc.*,
            .parent = parent_texture,
        };

        if (self.descriptor.state.shader_resource) {
            self.d3d_descriptor = resources.srv_heap.allocateOneDescriptor() catch
                return gpu.TextureView.Error.TextureViewFailedToCreate;
            errdefer resources.srv_heap.releaseDescriptor(self.d3d_descriptor);

            try self.createSRV();
            self.resources.srv_heap.copyToShaderVisibleHeap(self.d3d_descriptor, null);
            self.source_heap = .srv;
        } else if (self.descriptor.state.unordered_access) {
            self.d3d_descriptor = resources.srv_heap.allocateOneDescriptor() catch
                return gpu.TextureView.Error.TextureViewFailedToCreate;
            errdefer resources.srv_heap.releaseDescriptor(self.d3d_descriptor);

            try self.createUAV();
            self.resources.srv_heap.copyToShaderVisibleHeap(self.d3d_descriptor, null);
            self.source_heap = .srv;
        } else if (self.descriptor.state.render_target) {
            self.d3d_descriptor = resources.dsv_heap.allocateOneDescriptor() catch
                return gpu.TextureView.Error.TextureViewFailedToCreate;
            errdefer resources.dsv_heap.releaseDescriptor(self.d3d_descriptor);

            try self.createRTV();
            self.source_heap = .rtv;
        } else if (self.descriptor.state.depth_read or self.descriptor.state.depth_write) {
            self.d3d_descriptor = resources.dsv_heap.allocateOneDescriptor() catch
                return gpu.TextureView.Error.TextureViewFailedToCreate;
            errdefer resources.dsv_heap.releaseDescriptor(self.d3d_descriptor);

            try self.createDSV();
            self.source_heap = .dsv;
        }

        return self;
    }

    pub fn deinit(self: *TextureView) void {
        switch (self.source_heap) {
            .rtv => self.resources.rtv_heap.releaseDescriptor(self.descriptor),
            .dsv => self.resources.dsv_heap.releaseDescriptor(self.descriptor),
            .srv => self.resources.srv_heap.releaseDescriptor(self.descriptor),
            else => {},
        }
    }

    fn createSRV(
        self: *TextureView,
    ) !void {
        const subresources = self.descriptor.subresources.resolve(
            &self.parent.descriptor,
            false,
        );

        if (self.descriptor.dimension == .unknown)
            self.descriptor.dimension = self.parent.descriptor.dimension;

        var srv_desc: d3d12.D3D12_SHADER_RESOURCE_VIEW_DESC = undefined;
        srv_desc.Format = conv.getFormatMapping(if (self.descriptor.format == .unknown)
            self.parent.descriptor.format
        else
            self.descriptor.format).srv;
        srv_desc.Shader4ComponentMapping = d3d12.D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;

        const plane_slice: u32 = if (srv_desc.Format == .X24_TYPELESS_G8_UINT) 1 else 0;

        switch (self.descriptor.dimension) {
            .texture_1d => {
                srv_desc.ViewDimension = .TEXTURE1D;
                srv_desc.Anonymous.Texture1D = .{
                    .MostDetailedMip = subresources.base_mip_level,
                    .MipLevels = subresources.num_mip_levels,
                    .ResourceMinLODClamp = 0.0,
                };
            },
            .texture_1d_array => {
                srv_desc.ViewDimension = .TEXTURE1DARRAY;
                srv_desc.Anonymous.Texture1DArray = .{
                    .MostDetailedMip = subresources.base_mip_level,
                    .MipLevels = subresources.num_mip_levels,
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                    .ResourceMinLODClamp = 0.0,
                };
            },
            .texture_2d => {
                srv_desc.ViewDimension = .TEXTURE2D;
                srv_desc.Anonymous.Texture2D = .{
                    .MostDetailedMip = subresources.base_mip_level,
                    .MipLevels = subresources.num_mip_levels,
                    .PlaneSlice = plane_slice,
                    .ResourceMinLODClamp = 0.0,
                };
            },
            .texture_2d_array => {
                srv_desc.ViewDimension = .TEXTURE2DARRAY;
                srv_desc.Anonymous.Texture2DArray = .{
                    .MostDetailedMip = subresources.base_mip_level,
                    .MipLevels = subresources.num_mip_levels,
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                    .PlaneSlice = plane_slice,
                    .ResourceMinLODClamp = 0.0,
                };
            },
            .texture_cube => {
                srv_desc.ViewDimension = .TEXTURECUBE;
                srv_desc.Anonymous.TextureCube = .{
                    .MostDetailedMip = subresources.base_mip_level,
                    .MipLevels = subresources.num_mip_levels,
                    .ResourceMinLODClamp = 0.0,
                };
            },
            .texture_cube_array => {
                srv_desc.ViewDimension = .TEXTURECUBEARRAY;
                srv_desc.Anonymous.TextureCubeArray = .{
                    .MostDetailedMip = subresources.base_mip_level,
                    .MipLevels = subresources.num_mip_levels,
                    .First2DArrayFace = subresources.base_array_slice / 6,
                    .NumCubes = subresources.num_array_slices,
                    .ResourceMinLODClamp = 0.0,
                };
            },
            .texture_2d_ms => {
                srv_desc.ViewDimension = .TEXTURE2DMS;
                srv_desc.Anonymous.Texture2DMS = .{};
            },
            .texture_2d_ms_array => {
                srv_desc.ViewDimension = .TEXTURE2DMSARRAY;
                srv_desc.Anonymous.Texture2DMSArray = .{
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                };
            },
            .texture_3d => {
                srv_desc.ViewDimension = .TEXTURE3D;
                srv_desc.Anonymous.Texture3D = .{
                    .MostDetailedMip = subresources.base_mip_level,
                    .MipLevels = subresources.num_mip_levels,
                    .ResourceMinLODClamp = 0.0,
                };
            },
            else => unreachable,
        }

        self.parent.context.device.?.ID3D12Device_CreateShaderResourceView(self.parent.resource, &srv_desc, .{
            .ptr = self.descriptor,
        });
    }

    fn createUAV(
        self: *TextureView,
    ) !void {
        const subresources = self.descriptor.subresources.resolve(
            &self.parent.descriptor,
            true,
        );

        if (self.descriptor.dimension == .unknown)
            self.descriptor.dimension = self.parent.descriptor.dimension;

        var uav_desc: d3d12.D3D12_UNORDERED_ACCESS_VIEW_DESC = undefined;
        uav_desc.Format = conv.getFormatMapping(if (self.descriptor.format == .unknown)
            self.parent.descriptor.format
        else
            self.descriptor.format).srv;

        switch (self.parent.descriptor.dimension) {
            .texture_1d => {
                uav_desc.ViewDimension = .TEXTURE1D;
                uav_desc.Anonymous.Texture1D = .{
                    .MipSlice = subresources.base_mip_level,
                };
            },
            .texture_1d_array => {
                uav_desc.ViewDimension = .TEXTURE1DARRAY;
                uav_desc.Anonymous.Texture1DArray = .{
                    .MipSlice = subresources.base_mip_level,
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                };
            },
            .texture_2d => {
                uav_desc.ViewDimension = .TEXTURE2D;
                uav_desc.Anonymous.Texture2D = .{
                    .MipSlice = subresources.base_mip_level,
                    .PlaneSlice = 0,
                };
            },
            .texture_2d_array, .texture_cube, .texture_cube_array => {
                uav_desc.ViewDimension = .TEXTURE2DARRAY;
                uav_desc.Anonymous.Texture2DArray = .{
                    .MipSlice = subresources.base_mip_level,
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                    .PlaneSlice = 0,
                };
            },
            .texture_3d => {
                uav_desc.ViewDimension = .TEXTURE3D;
                uav_desc.Anonymous.Texture3D = .{
                    .MipSlice = subresources.base_mip_level,
                    .FirstWSlice = 0,
                    .WSize = self.parent.descriptor.depth,
                };
            },
            .texture_2d_ms, .texture_2d_ms_array => {
                return gpu.TextureView.Error.TextureViewUnsupportedDimensionForUAV;
            },
            else => unreachable,
        }

        self.parent.context.device.?.ID3D12Device_CreateUnorderedAccessView(
            self.parent.resource,
            null,
            &uav_desc,
            .{
                .ptr = self.d3d_descriptor,
            },
        );
    }

    fn createRTV(
        self: *TextureView,
    ) !void {
        const subresources = self.descriptor.subresources.resolve(
            &self.parent.descriptor,
            true,
        );

        var rtv_desc: d3d12.D3D12_RENDER_TARGET_VIEW_DESC = undefined;
        rtv_desc.Format = conv.getFormatMapping(if (self.descriptor.format == .unknown)
            self.parent.descriptor.format
        else
            self.descriptor.format).rtv;

        switch (self.parent.descriptor.dimension) {
            .texture_1d => {
                rtv_desc.ViewDimension = .TEXTURE1D;
                rtv_desc.Anonymous.Texture1D = .{
                    .MipSlice = subresources.base_mip_level,
                };
            },
            .texture_1d_array => {
                rtv_desc.ViewDimension = .TEXTURE1DARRAY;
                rtv_desc.Anonymous.Texture1DArray = .{
                    .MipSlice = subresources.base_mip_level,
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                };
            },
            .texture_2d => {
                rtv_desc.ViewDimension = .TEXTURE2D;
                rtv_desc.Anonymous.Texture2D = .{
                    .MipSlice = subresources.base_mip_level,
                    .PlaneSlice = 0,
                };
            },
            .texture_2d_array, .texture_cube, .texture_cube_array => {
                rtv_desc.ViewDimension = .TEXTURE2DARRAY;
                rtv_desc.Anonymous.Texture2DArray = .{
                    .MipSlice = subresources.base_mip_level,
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                    .PlaneSlice = 0,
                };
            },
            .texture_2d_ms => {
                rtv_desc.ViewDimension = .TEXTURE2DMS;
                rtv_desc.Anonymous.Texture2DMS = undefined;
            },
            .texture_2d_ms_array => {
                rtv_desc.ViewDimension = .TEXTURE2DMSARRAY;
                rtv_desc.Anonymous.Texture2DMSArray = .{
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                };
            },
            .texture_3d => {
                rtv_desc.ViewDimension = .TEXTURE3D;
                rtv_desc.Anonymous.Texture3D = .{
                    .MipSlice = subresources.base_mip_level,
                    .FirstWSlice = subresources.base_array_slice,
                    .WSize = subresources.num_array_slices,
                };
            },
            else => unreachable,
        }

        self.parent.context.device.?.ID3D12Device_CreateRenderTargetView(
            self.parent.resource,
            &rtv_desc,
            .{
                .ptr = self.d3d_descriptor,
            },
        );
    }

    fn createDSV(
        self: *TextureView,
    ) !void {
        const is_readonly = !self.descriptor.state.depth_write;

        const subresources = self.descriptor.subresources.resolve(
            &self.parent.descriptor,
            true,
        );

        var dsv_desc: d3d12.D3D12_DEPTH_STENCIL_VIEW_DESC = undefined;
        dsv_desc.Format = conv.getFormatMapping(self.descriptor.format).rtv;

        if (is_readonly) {
            dsv_desc.Flags = d3d12.D3D12_DSV_FLAGS.initFlags(.{
                .READ_ONLY_DEPTH = true,
                .READ_ONLY_STENCIL = (dsv_desc.Format == .D32_FLOAT_S8X24_UINT or
                    dsv_desc.Format == .D24_UNORM_S8_UINT),
            });
        }

        switch (self.parent.descriptor.dimension) {
            .texture_1d => {
                dsv_desc.ViewDimension = .TEXTURE1D;
                dsv_desc.Anonymous.Texture1D = .{
                    .MipSlice = subresources.base_mip_level,
                };
            },
            .texture_1d_array => {
                dsv_desc.ViewDimension = .TEXTURE1DARRAY;
                dsv_desc.Anonymous.Texture1DArray = .{
                    .MipSlice = subresources.base_mip_level,
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                };
            },
            .texture_2d => {
                dsv_desc.ViewDimension = .TEXTURE2D;
                dsv_desc.Anonymous.Texture2D = .{
                    .MipSlice = subresources.base_mip_level,
                };
            },
            .texture_2d_array, .texture_cube, .texture_cube_array => {
                dsv_desc.ViewDimension = .TEXTURE2DARRAY;
                dsv_desc.Anonymous.Texture2DArray = .{
                    .MipSlice = subresources.base_mip_level,
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                };
            },
            .texture_2d_ms => {
                dsv_desc.ViewDimension = .TEXTURE2DMS;
            },
            .texture_2d_ms_array => {
                dsv_desc.ViewDimension = .TEXTURE2DMSARRAY;
                dsv_desc.Anonymous.Texture2DMSArray = .{
                    .FirstArraySlice = subresources.base_array_slice,
                    .ArraySize = subresources.num_array_slices,
                };
            },
            else => {
                return gpu.TextureView.Error.TextureViewUnsupportedDimensionForDSV;
            },
        }

        self.parent.context.device.?.ID3D12Device_CreateDepthStencilView(
            self.parent.resource,
            &dsv_desc,
            .{
                .ptr = self.d3d_descriptor,
            },
        );
    }
};

pub const Queue = struct {
    pub const Error = error{
        QueueFailedToCreate,
    };

    context: *const Context,
    queue: ?*d3d12.ID3D12CommandQueue = null,
    fence: ?*d3d12.ID3D12Fence = null,

    last_submitted_instance: u64 = 0,
    last_completed_instance: u64 = 0,
    recording_instance: std.atomic.Value(u64) = std.atomic.Value(u64).init(1),
    // command_lists_inf_flight: std.ArrayList(?*d3d12.ID3D12CommandList),

    pub fn init(context: *const Context, desc: *const d3d12.D3D12_COMMAND_QUEUE_DESC) !*Queue {
        const self = allocator.create(Queue) catch return Error.QueueFailedToCreate;
        errdefer allocator.destroy(self);
        self.* = .{
            .context = context,
        };

        _ = context.device.?.ID3D12Device_CreateCommandQueue(
            desc,
            d3d12.IID_ID3D12CommandQueue,
            @ptrCast(&self.queue),
        );

        _ = context.device.?.ID3D12Device_CreateFence(
            0,
            .NONE,
            d3d12.IID_ID3D12Fence,
            @ptrCast(&self.fence),
        );

        return self;
    }

    pub fn deinit(self: *Queue) void {
        d3dcommon.releaseIUnknown(d3d12.ID3D12CommandQueue, &self.queue);
        d3dcommon.releaseIUnknown(d3d12.ID3D12Fence, &self.fence);
    }

    pub fn updateLastCompletedInstance(self: *Queue) u64 {
        if (self.last_completed_instance < self.last_submitted_instance) {
            self.last_completed_instance = self.fence.?.ID3D12Fence_GetCompletedValue();
        }
        return self.last_completed_instance;
    }
};

// Device
pub fn deviceCreateSwapChain(
    device: *gpu.Device,
    surface: ?*gpu.Surface,
    desc: *const gpu.SwapChain.Descriptor,
) gpu.SwapChain.Error!*gpu.SwapChain {
    std.debug.print("creating swap chain...\n", .{});
    return @ptrCast(
        try D3D12SwapChain.init(@ptrCast(
            @alignCast(device),
        ), @ptrCast(@alignCast(surface.?)), desc),
    );
}

pub fn deviceCreateHeap(
    device: *gpu.Device,
    desc: *const gpu.Heap.Descriptor,
) gpu.Heap.Error!*gpu.Heap {
    std.debug.print("creating heap...\n", .{});
    return @ptrCast(
        try D3D12Device.createHeap(
            @ptrCast(@alignCast(device)),
            desc,
        ),
    );
}

pub fn deviceCreateTexture(
    device: *gpu.Device,
    desc: *const gpu.Texture.Descriptor,
    resource_desc: *const d3d12.D3D12_RESOURCE_DESC,
) gpu.Texture.Error!*gpu.Texture {
    std.debug.print("creating texture...\n", .{});
    return @ptrCast(
        try D3D12Texture.init(
            @ptrCast(@alignCast(device)),
            @ptrCast(@alignCast(device.resources)),
            desc,
            resource_desc,
        ),
    );
}
)

pub fn deviceDestroy(device: *gpu.Device) void {
    std.debug.print("destroying device...\n", .{});
    D3D12Device.deinit(@alignCast(@ptrCast(device)));
}

pub const D3D12Device = struct {
    physical_device: *D3D12PhysicalDevice,

    context: Context,
    resources: DeviceResources,

    queues: [std.enums.values(gpu.CommandQueue).len]?*Queue = .{ null, null, null },

    fence_event: win32.foundation.HANDLE,
    options: d3d12.D3D12_FEATURE_DATA_D3D12_OPTIONS = undefined,
    mutex: std.Thread.Mutex = .{},

    command_lists: std.ArrayList(*d3d12.ID3D12CommandList),

    lost_cb: ?gpu.Device.LostCallback = null,

    pub fn init(physical_device: *D3D12PhysicalDevice, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*D3D12Device {
        const self = allocator.create(D3D12Device) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer allocator.destroy(self);
        self.* = .{
            .physical_device = physical_device,
            // .queue = queue,
            .context = .{},
            .resources = undefined,
            .lost_cb = desc.lost_callback,
        };
        self.resources.init(&self.context);

        const hr = d3d12.D3D12CreateDevice(
            @ptrCast(self.physical_device.adapter),
            .@"11_0",
            d3d12.IID_ID3D12Device2,
            @ptrCast(&self.context.device),
        );
        if (!d3dcommon.checkHResult(hr)) return gpu.Device.Error.DeviceFailedToCreate;
        errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12Device2, &self.context.device);

        const info_hr = self.context.device.?.ID3D12Device_CheckFeatureSupport(
            d3d12.D3D12_FEATURE_D3D12_OPTIONS,
            @ptrCast(&self.options),
            d3d12.D3D12_FEATURE_D3D12_OPTIONS.sizeof,
        );
        if (!d3dcommon.checkHResult(info_hr)) return gpu.Device.Error.DeviceFailedToCreate;

        if (self.physical_device.instance.debug) {
            var info_queue: ?*d3d12.ID3D12InfoQueue = null;
            if (winapi.zig.SUCCEEDED(
                self.context.device.?.IUnknown_QueryInterface(d3d12.IID_ID3D12InfoQueue, @ptrCast(&info_queue)),
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

        // Create command queues
        var queue_desc: d3d12.D3D12_COMMAND_QUEUE_DESC =
            std.mem.zeroes(d3d12.D3D12_COMMAND_QUEUE_DESC);
        queue_desc.Flags = .NONE;
        queue_desc.NodeMask = 1;

        for (.{
            d3d12.D3D12_COMMAND_LIST_TYPE_DIRECT,
            d3d12.D3D12_COMMAND_LIST_TYPE_COMPUTE,
            d3d12.D3D12_COMMAND_LIST_TYPE_COPY,
        }, 0..) |ty, index| {
            queue_desc.Type = ty;

            var queue: ?*d3d12.ID3D12CommandQueue = null;
            const queue_hr = self.context.device.?.ID3D12Device_CreateCommandQueue(
                &queue_desc,
                d3d12.IID_ID3D12CommandQueue,
                @ptrCast(&queue),
            );
            if (!d3dcommon.checkHResult(queue_hr)) return gpu.Device.Error.DeviceFailedToCreate;
            errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12CommandQueue, &queue);

            self.queues[index] = try Queue.init(self.context, queue);
        }
        errdefer {
            for (self.queues) |queue| {
                if (queue) |q| q.deinit();
            }
        }

        try self.resources.dsv_heap.allocateResources(
            .DSV,
            depth_stencil_view_heap_size,
            false,
        );
        try self.resources.rtv_heap.allocateResources(
            .RTV,
            render_target_view_heap_size,
            false,
        );
        try self.resources.srv_heap.allocateResources(
            .CBV_SRV_UAV,
            shader_resource_view_heap_size,
            true,
        );
        try self.resources.sampler_heap.allocateResources(
            .SAMPLER,
            sampler_heap_size,
            true,
        );

        return self;
    }

    pub fn deinit(self: *D3D12Device) void {
        if (self.lost_cb) |cb| {
            cb(.destroyed, "device destroyed");
        }
        // _ = self.queue.waitUntil(self.queue.fence_value);
        self.waitForIdle();

        for (self.queues) |queue| {
            if (queue) |q| q.deinit();
        }

        // self.queue.deinit();
        // allocator.destroy(self.queue);
        self.context.deinit();
        allocator.destroy(self);
    }

    pub fn createHeap(
        self: *D3D12Device,
        desc: *const gpu.Heap.Descriptor,
    ) gpu.Heap.Error!*gpu.Heap {
        var heap_desc: d3d12.D3D12_HEAP_DESC = undefined;
        heap_desc.SizeInBytes = desc.capacity;
        heap_desc.Alignment = d3d12.D3D12_DEFAULT_MSAA_RESOURCE_PLACEMENT_ALIGNMENT;
        heap_desc.Properties = .{
            .Type = .DEFAULT,
            .CPUPageProperty = .UNKNOWN,
            .MemoryPoolPreference = .UNKNOWN,
            .CreationNodeMask = 1,
            .VisibleNodeMask = 1,
        };

        if (self.options.ResourceHeapTier == .@"1") {
            heap_desc.Flags = .ALLOW_ONLY_NON_RT_DS_TEXTURES;
        } else {
            heap_desc.Flags = .NONE;
        }

        heap_desc.Properties.Type = switch (desc.type) {
            .device_local => .DEFAULT,
            .upload => .UPLOAD,
            .readback => .READBACK,
        };

        var d3d_heap: ?*d3d12.ID3D12Heap = null;
        const heap_hr = self.context.device.?.ID3D12Device_CreateHeap(
            &heap_desc,
            d3d12.IID_ID3D12Heap,
            @ptrCast(&d3d_heap),
        );
        if (!d3dcommon.checkHResult(heap_hr)) return gpu.Heap.Error.HeapFailedToCreate;
        errdefer d3dcommon.releaseIUnknown(d3d12.ID3D12Heap, &d3d_heap);

        if (desc.debug_label) |dbgl| {
            var scratch = common.ScratchSpace(256){};
            const temp_allocator = scratch.init().allocator();

            d3d_heap.?.ID3D12Object_SetName(winappimpl.convertToUtf16WithAllocator(
                temp_allocator,
                dbgl,
            ) orelse
                "<dbgname>");
        }

        const heap = allocator.create(Heap) catch return gpu.Heap.Error.HeapFailedToCreate;
        heap.heap = d3d_heap;
        heap.descriptor = desc.*;
        return heap;
    }

    pub fn waitForIdle(self: *D3D12Device) void {
        for (self.queues) |queue| {
            if (queue == null) continue;

            if (queue.updateLastCompletedInstance() < queue.last_submitted_instance) {
                waitForFence(queue.fence, queue.last_submitted_instance, self.fence_event);
            }
        }
    }

    pub fn getQueue(self: *D3D12Device, ty: gpu.CommandQueue) *Queue {
        return self.queues[@intFromEnum(ty)].?;
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

pub var allocator: std.mem.Allocator = undefined;
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
    // textures: [3]?*D3D12Texture = .{ null, null, null },
    // views: [3]?*D3D12TextureView = .{ null, null, null },
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
        _ = self;

        // var textures: [3]?*D3D12Texture = undefined;
        // var views: [3]?*D3D12TextureView = undefined;
        const fences: [3]u64 = undefined;
        _ = fences;

        // for (0..self.buffer_count) |index| {
        //     var buffer: ?*d3d12.ID3D12Resource = null;
        //     const buffer_hr = self.swapchain.?.IDXGISwapChain_GetBuffer(
        //         @intCast(index),
        //         d3d12.IID_ID3D12Resource,
        //         @ptrCast(&buffer),
        //     );
        //     if (!d3dcommon.checkHResult(buffer_hr)) return gpu.SwapChain.Error.SwapChainFailedToCreate;

        //     const texture = D3D12Texture.initSwapChain(
        //         self.device,
        //         &self.desc,
        //         buffer,
        //     ) catch return gpu.SwapChain.Error.SwapChainFailedToCreate;
        //     const view = texture.createView(&.{}) catch return gpu.SwapChain.Error.SwapChainFailedToCreate;

        //     textures[index] = texture;
        //     views[index] = view;
        //     fences[index] = 0;
        // }

        // self.textures = textures;
        // self.views = views;
        // self.fences = fences;
    }

    fn releaseRenderTargets(self: *D3D12SwapChain) void {
        _ = self.device.queue.waitUntil(self.device.queue.fence_value);

        // for (self.views[0..self.buffer_count]) |*view| {
        //     if (view.*) |v| {
        //         v.deinit();
        //         view.* = null;
        //     }
        // }
        // for (self.textures[0..self.buffer_count]) |*texture| {
        //     if (texture.*) |t| {
        //         t.deinit();
        //         texture.* = null;
        //     }
        // }
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
