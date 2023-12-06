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

const d3dcommon = @import("../d3d/common.zig");

const common = @import("../../core/common.zig");

// Loading
pub const procs: gpu.procs.Procs = .{ // Heap
    .heapGetDescriptor = heapGetDescriptor,
    .heapDestroy = heapDestroy,

    // Texture
    .textureGetDescriptor = textureGetDescriptor,
    .textureDestroy = textureDestroy,

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

    // ShaderLibrary
    .shaderLibraryGetBytecode = shaderLibraryGetBytecode,
    .shaderLibraryGetShader = shaderLibraryGetShader,
    .shaderLibraryDestroy = shaderLibraryDestroy,

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

// Device
pub fn deviceCreateSwapChain(
    device: *gpu.Device,
    surface: ?*gpu.Surface,
    desc: *const gpu.SwapChain.Descriptor,
) gpu.SwapChain.Error!*gpu.SwapChain {
    std.debug.print("creating swap chain...\n", .{});
    return @ptrCast(try D3D12SwapChain.init(@ptrCast(@alignCast(device)), @ptrCast(@alignCast(surface.?)), desc));
}

pub fn deviceDestroy(device: *gpu.Device) void {
    std.debug.print("destroying device...\n", .{});
    D3D12Device.deinit(@alignCast(@ptrCast(device)));
}

pub const D3D12Device = struct {
    physical_device: *D3D12PhysicalDevice,

    device: ?*d3d12.ID3D12Device2 = null, // PhysicalDevice
    lost_cb: ?gpu.Device.LostCallback = null,

    pub fn init(physical_device: *D3D12PhysicalDevice, desc: *const gpu.Device.Descriptor) gpu.Device.Error!*D3D12Device {
        // const queue = allocator.create(D3D12Queue) catch return gpu.Device.Error.DeviceFailedToCreate;
        // errdefer allocator.destroy(queue);

        const self = allocator.create(D3D12Device) catch return gpu.Device.Error.DeviceFailedToCreate;
        errdefer allocator.destroy(self);
        self.* = .{
            .physical_device = physical_device,
            // .queue = queue,
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

        // self.queue.* = D3D12Queue.init(self) catch return gpu.Device.Error.DeviceFailedToCreate;
        // errdefer D3D12Queue.deinit(queue);

        // TODO: heaps

        // self.general_heap = D3D12DescriptorHeap.init(
        //     self,
        //     .CBV_SRV_UAV,
        //     .SHADER_VISIBLE,
        //     general_heap_size,
        //     general_block_size,
        // ) catch return gpu.Device.Error.DeviceFailedToCreate;
        // errdefer self.general_heap.deinit();

        // self.sampler_heap = D3D12DescriptorHeap.init(
        //     self,
        //     .SAMPLER,
        //     .SHADER_VISIBLE,
        //     sampler_heap_size,
        //     sampler_block_size,
        // ) catch return gpu.Device.Error.DeviceFailedToCreate;
        // errdefer self.sampler_heap.deinit();

        // self.rtv_heap = D3D12DescriptorHeap.init(
        //     self,
        //     .RTV,
        //     .NONE,
        //     rtv_heap_size,
        //     rtv_block_size,
        // ) catch return gpu.Device.Error.DeviceFailedToCreate;
        // errdefer self.rtv_heap.deinit();

        // self.dsv_heap = D3D12DescriptorHeap.init(
        //     self,
        //     .DSV,
        //     .NONE,
        //     dsv_heap_size,
        //     dsv_block_size,
        // ) catch return gpu.Device.Error.DeviceFailedToCreate;
        // errdefer self.dsv_heap.deinit();

        // self.command_pool = D3D12CommandPool.init(self);
        // self.streaming_pool = D3D12StreamingPool.init(self);
        // self.resource_pool = D3D12ResourcePool.init(self);

        return self;
    }

    pub fn deinit(self: *D3D12Device) void {
        if (self.lost_cb) |cb| {
            cb(.destroyed, "device destroyed");
        }
        // _ = self.queue.waitUntil(self.queue.fence_value);

        // self.queue.deinit();
        // allocator.destroy(self.queue);
        d3dcommon.releaseIUnknown(d3d12.ID3D12Device2, &self.device);
        allocator.destroy(self);
    }

    pub fn getQueue(self: *D3D12Device) *gpu.Queue {
        return @ptrCast(@alignCast(self.queue));
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
