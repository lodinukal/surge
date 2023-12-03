const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");

const gpu = @import("render/gpu.zig");

const RenderContext = struct {
    instance: *gpu.Instance = undefined,
    surface: *gpu.Surface = undefined,
    physical_device: *gpu.PhysicalDevice = undefined,
    device: *gpu.Device = undefined,

    swapchain: *gpu.SwapChain = undefined,

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
        self.swapchain = swapchain;
    }

    pub fn deinit(self: *RenderContext) void {
        self.swapchain.destroy();
        self.device.destroy();
        self.physical_device.destroy();
        self.surface.destroy();
        self.instance.destroy();
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

            if (self.resized) |size| {
                try self.render.swapchain.resize(size);
            }
            try self.render.swapchain.present();
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
