const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");

const gpu = @import("render/gpu.zig");

/// Based off a wgpu-native example:
/// https://github.com/samdauwe/webgpu-native-examples/blob/master/src/examples/triangle.c
const RenderContext = struct {
    pub const Vertex = struct {
        position: math.Vec,
        colour: math.Vec,
    };

    instance: *gpu.Instance = undefined,
    surface: *gpu.Surface = undefined,
    physical_device: *gpu.PhysicalDevice = undefined,
    device: *gpu.Device = undefined,
    queue: *gpu.Queue = undefined,

    swapchain: *gpu.SwapChain = undefined,

    // rendering objects

    vertex_buffer: ?*gpu.Buffer = null,
    vertex_count: usize = 0,

    index_buffer: ?*gpu.Buffer = null,
    index_count: usize = 0,

    uniform_buffer: ?*gpu.Buffer = null,
    uniform_count: usize = 0,

    pipeline_layout: ?*gpu.PipelineLayout = null,

    render_pipeline: ?*gpu.RenderPipeline = null,

    render_pass: struct {
        colour_attachment: [1]gpu.RenderPass.ColourAttachment = .{undefined},
        descriptor: gpu.RenderPass.Descriptor = .{},
    } = .{},

    pub fn load(self: *RenderContext, context: *Context) !void {
        if (gpu.loadBackend(.d3d12) == false) return;
        const instance = try gpu.createInstance(context.allocator, &.{});
        errdefer instance.destroy();

        const surface = try instance.createSurface(&.{
            .native_handle = context.window.getNativeHandle().wnd,
            .native_handle_size = 8,
        });
        errdefer surface.destroy();

        const physicalDevice = try instance.requestPhysicalDevice(&.{
            .power_preference = .high_performance,
        });
        errdefer physicalDevice.destroy();

        const device = try physicalDevice.createDevice(&.{ .label = "device" });
        errdefer device.destroy();

        const swapchain = try device.createSwapChain(surface, &.{
            .height = 600,
            .width = 800,
            .present_mode = .mailbox,
            .format = .bgra8_unorm,
            .usage = .{
                .render_attachment = true,
            },
        });
        errdefer swapchain.destroy();

        self.instance = instance;
        self.surface = surface;
        self.physical_device = physicalDevice;
        self.device = device;
        self.queue = device.getQueue();
        self.swapchain = swapchain;

        try self.loadResources();
    }

    pub fn deinit(self: *RenderContext) void {
        self.cleanResources();

        self.swapchain.destroy();
        self.device.destroy();
        self.physical_device.destroy();
        self.surface.destroy();
        self.instance.destroy();
    }

    fn loadResources(self: *RenderContext) !void {
        try self.prepareVertexAndIndexBuffers();
    }

    fn cleanResources(self: *RenderContext) void {
        if (self.vertex_buffer) |b| b.destroy();
        if (self.index_buffer) |b| b.destroy();
        if (self.uniform_buffer) |b| b.destroy();
        if (self.pipeline_layout) |pl| pl.destroy();
        // if (self.render_pipeline) |rp| rp.destroy();
    }

    fn createUploadedBuffer(self: *RenderContext, usage: gpu.Buffer.UsageFlags, comptime T: type, data: []const T) !*gpu.Buffer {
        var modified_usage = usage;
        modified_usage.copy_dst = true;
        var buffer = try self.device.createBuffer(&.{
            .usage = modified_usage,
            .size = data.len * @sizeOf(T),
        });
        errdefer buffer.destroy();

        try self.queue.writeBuffer(buffer, 0, T, data);

        return buffer;
    }

    fn prepareVertexAndIndexBuffers(self: *RenderContext) !void {
        const vertices = [3]Vertex{
            .{
                .position = .{ 0.0, 0.5, 0.0, 0.0 },
                .colour = .{ 1.0, 0.0, 0.0, 1.0 },
            },
            .{
                .position = .{ 0.5, -0.5, 0.0, 0.0 },
                .colour = .{ 0.0, 1.0, 0.0, 1.0 },
            },
            .{
                .position = .{ -0.5, -0.5, 0.0, 0.0 },
                .colour = .{ 0.0, 0.0, 1.0, 1.0 },
            },
        };
        self.vertex_count = vertices.len;

        const indices = [4]u16{ 0, 1, 2, 0 };
        self.index_count = indices.len;

        self.vertex_buffer = try self.createUploadedBuffer(.{
            .vertex = true,
        }, Vertex, &vertices);

        self.index_buffer = try self.createUploadedBuffer(.{
            .index = true,
        }, u16, &indices);
    }
};

const Context = struct {
    allocator: std.mem.Allocator,
    application: *app.Application,
    window: *app.window.Window,

    ui_thread: ?std.Thread = null,
    mutex: std.Thread.Mutex = .{},

    ready_condition: std.Thread.Condition = .{},
    ready_mutex: std.Thread.Mutex = .{},

    render: RenderContext = .{},
    resized: ?[2]u32 = null,

    pub fn init(allocator: std.mem.Allocator) !Context {
        var application = try app.Application.create(allocator);
        errdefer application.destroy();

        // application.input.focused_changed_callback = focused_changed_callback;
        application.input.input_began_callback = inputBeganCallback;
        application.input.input_changed_callback = inputChangedCallback;
        application.input.input_ended_callback = inputEndedCallback;
        application.input.frame_update_callback = frameUpdate;

        return Context{
            .allocator = allocator,
            .application = application,
            .window = try application.createWindow(.{
                .title = "helloo!",
                .size = .{ 800, 600 },
                .visible = true,
            }),
        };
    }

    pub fn deinit(self: *Context) void {
        if (self.ui_thread) |t| {
            t.join();
        }
        self.window.destroy();
        self.application.destroy();
    }

    pub fn pumpEvents(self: *Context) !void {
        try self.application.pumpEvents();
    }

    pub fn running(self: *Context) bool {
        return !self.window.shouldClose();
    }

    pub fn spawnWindowThread(self: *Context) !void {
        self.ui_thread = try std.Thread.spawn(.{
            .allocator = self.allocator,
        }, windowLoop, .{self});
        self.ready_mutex.lock();
        defer self.ready_mutex.unlock();
        self.ready_condition.wait(&self.ready_mutex);
    }

    pub const focused_sleep = std.time.ns_per_us * 100;
    pub const unfocused_sleep = std.time.ns_per_ms * 10;

    fn windowLoop(self: *Context) !void {
        try self.window.build();

        self.window.storeContext(Context, self);

        self.ready_mutex.lock();
        self.ready_condition.broadcast();
        self.ready_mutex.unlock();

        try self.render.load(self);

        while (self.running()) {
            try self.pumpEvents();
            self.window.setTitle(if (self.window.isFocused()) "focused" else "not focused");

            const frame_start = std.time.nanoTimestamp();

            if (self.resized) |size| {
                try self.render.swapchain.resize(size);
            }
            try self.render.swapchain.present();

            const frame_end = std.time.nanoTimestamp();

            const frame_time = frame_end - frame_start;
            _ = frame_time;
            // std.debug.print("frame time: {d:1}\n", .{1000.0 / @as(f64, @floatFromInt(frame_time))});

            std.time.sleep(if (self.window.isFocused()) focused_sleep else unfocused_sleep);
        }

        self.render.deinit();
    }

    fn frameUpdate(wnd: *app.window.Window) void {
        _ = wnd;
    }

    fn inputBeganCallback(ipo: app.input.InputObject) void {
        _ = ipo;
    }

    fn inputChangedCallback(ipo: app.input.InputObject) void {
        if (ipo.type == .resize) {
            var ctx = ipo.window.?.getContext(Context).?;
            ctx.resized = .{
                @intCast(ipo.data.resize[0]),
                @intCast(ipo.data.resize[1]),
            };
        }
    }

    fn inputEndedCallback(ipo: app.input.InputObject) void {
        _ = ipo;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    // defer arena.deinit();
    // const alloc = arena.allocator();

    var context = try Context.init(alloc);
    defer context.deinit();

    try context.spawnWindowThread();

    // std.debug.print("mem: {}\n", .{arena.queryCapacity()});

    var start = std.time.timestamp();
    while (context.running()) {
        if (std.time.timestamp() - start > 100) {
            start = std.time.timestamp();
            context.window.setVisible(!context.window.isVisible());
        }
        std.time.sleep(std.time.ns_per_s);
    }

    // std.debug.print("mem: {}\n", .{arena.queryCapacity()});
}
