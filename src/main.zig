const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");
const Renderer = @import("render/gpu/Renderer.zig");

const interface = @import("core/interface.zig");

const Vertex = struct {
    position: [2]f32,
    colour: [4]u8,
};

const RenderContext = struct {
    context: *Context = undefined,
    renderer: *Renderer = undefined,

    swapchain: Renderer.Handle(Renderer.SwapChain) = undefined,
    cached_size: ?[2]u32 = null,

    vertex_buffer: Renderer.Handle(Renderer.Buffer) = undefined,

    vertex_shader: Renderer.Handle(Renderer.Shader) = undefined,
    pixel_shader: Renderer.Handle(Renderer.Shader) = undefined,

    pub fn init(self: *RenderContext, ctx: *Context) !void {
        self.context = ctx;
        self.renderer = try Renderer.create(self.context.allocator, .{});
        errdefer self.renderer.destroy();
        try self.renderer.load(.d3d11);
    }

    pub fn deinit(self: *RenderContext) void {
        self.renderer.destroySwapchain(self.swapchain) catch {};
        self.renderer.destroy();
    }

    pub fn build(self: *RenderContext) !void {
        self.swapchain = try self.renderer.createSwapchain(&.{
            .resolution = .{ 800, 600 },
        }, self.context.window);

        try self.createResources();
    }

    pub fn resize(self: *RenderContext, size: [2]u32) !void {
        const old_cached_size = self.cached_size;
        _ = old_cached_size;
        self.cached_size = size;
    }

    pub fn processSizeChange(self: *RenderContext) !void {
        if (self.cached_size) |size| {
            var swapchain = try self.renderer.useSwapchainMutable(self.swapchain);
            try swapchain.resizeBuffers(
                .{
                    @intCast(size[0]),
                    @intCast(size[1]),
                },
                .{
                    .modify_surface = true,
                    .fullscreen = self.context.window.getFullscreenMode() == .fullscreen,
                },
            );
            self.cached_size = null;
        }
    }

    pub fn present(self: *RenderContext) !void {
        var swapchain = try self.renderer.useSwapchainMutable(self.swapchain);
        swapchain.present();
    }

    fn createResources(self: *RenderContext) !void {
        var buffer: [2048]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        var temp_allocator = fba.allocator();

        var vertex_format = Renderer.VertexFormat.init(temp_allocator);
        try vertex_format.appendAttribute(.{
            .name = "POS",
            .format = .rg32float,
        });
        try vertex_format.appendAttribute(.{
            .name = "COLOR",
            .format = .rgba8unorm,
        });
        vertex_format.setStride(@sizeOf(Vertex));

        var vertex_attributes = try vertex_format.done();

        try self.createBuffers(vertex_attributes);
        try self.createShaders(vertex_attributes);
    }

    fn createBuffers(self: *RenderContext, attributes: []const Renderer.VertexAttribute) !void {
        const vertices = [_]Vertex{
            .{ .position = .{ -0.5, -0.5 }, .colour = .{ 255, 0, 0, 255 } },
            .{ .position = .{ 0.5, -0.5 }, .colour = .{ 0, 255, 0, 255 } },
            .{ .position = .{ 0.0, 0.5 }, .colour = .{ 0, 0, 255, 255 } },
        };
        const as_data: []const u8 = @as([*]const u8, @ptrCast(&vertices))[0 .. vertices.len * @sizeOf(Vertex)];

        var buffer_descriptor = Renderer.Buffer.BufferDescriptor{
            .size = vertices.len * @sizeOf(Vertex),
            .binding = .{ .vertex_buffer = true },
            .vertex_attributes = attributes,
        };
        self.vertex_buffer = try self.renderer.createBuffer(&buffer_descriptor, as_data);
    }

    fn createShaders(self: *RenderContext, attributes: []const Renderer.VertexAttribute) !void {
        const src = @embedFile("shaders.hlsl");

        var desc: Renderer.Shader.ShaderDescriptor = .{
            .type = .vertex,
            .source = src,
            .entry_point = "vs_main",
            .profile = "vs_5_0",
            .vertex = .{
                .input = attributes,
            },
        };
        self.vertex_shader = try self.renderer.createShader(&desc);

        desc = .{
            .type = .fragment,
            .source = src,
            .entry_point = "ps_main",
            .profile = "ps_5_0",
        };
        self.pixel_shader = try self.renderer.createShader(&desc);
    }
};

const Context = struct {
    allocator: std.mem.Allocator = undefined,
    application: *app.Application = undefined,
    window: *app.window.Window = undefined,

    ui_thread: ?std.Thread = null,

    ready_condition: std.Thread.Condition = .{},
    ready_mutex: std.Thread.Mutex = .{},

    render_ctx: RenderContext = .{},

    pub fn create(allocator: std.mem.Allocator) !*Context {
        var context = try allocator.create(Context);
        context.* = .{};
        context.allocator = allocator;
        try context.init();

        return context;
    }

    pub fn destroy(self: *Context) void {
        self.deinit();
        self.allocator.destroy(self);
    }

    fn init(self: *Context) !void {
        self.application = try app.Application.create(self.allocator);
        errdefer self.application.destroy();

        try self.render_ctx.init(self);

        // application.input.focused_changed_callback = focused_changed_callback;
        self.application.input.input_began_callback = inputBeganCallback;
        self.application.input.input_changed_callback = inputChangedCallback;
        self.application.input.input_ended_callback = inputEndedCallback;
        self.application.input.frame_update_callback = frameUpdate;

        self.window = try self.application.createWindow(.{
            .title = "engine",
            .size = .{ 800, 600 },
            .visible = true,
        });
        self.window.storeContext(Context, self);
    }

    fn deinit(self: *Context) void {
        self.render_ctx.deinit();

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
        self.render_ctx.build() catch |err| {
            std.debug.print("failed to build render context: {}\n", .{err});
            return;
        };

        self.ready_mutex.lock();
        self.ready_condition.broadcast();
        self.ready_mutex.unlock();

        while (self.running()) {
            try self.pumpEvents();
            var char_buffer: [256]u8 = undefined;
            if (self.window.getPosition()) |pos| {
                const res = try std.fmt.bufPrint(&char_buffer, "{}x{}", .{ pos[0], pos[1] });
                self.window.setTitle(res);
            }
            std.time.sleep(if (self.window.isFocused()) focused_sleep else unfocused_sleep);

            try self.render_ctx.processSizeChange();
            self.render_ctx.present() catch |err| {
                std.debug.print("failed to present: {}\n", .{err});
                return;
            };

            frameUpdate(self.window);
        }
    }

    fn frameUpdate(wnd: *app.window.Window) void {
        _ = wnd;
    }

    fn inputBeganCallback(ipo: app.input.InputObject) void {
        if (ipo.type == .mousebutton) {
            std.debug.print("mousebutton {} down\n", .{ipo.data.mousebutton});
        }
        if (ipo.type == .textinput) {
            if (ipo.data.textinput == .short) {
                std.debug.print("{c}\n", .{ipo.data.textinput.short});
            }
        }
    }

    fn inputChangedCallback(ipo: app.input.InputObject) void {
        // std.debug.print("input changed: {}\n", .{ipo});
        if (ipo.type == .resize) {
            var context: *Context = @alignCast(ipo.window.?.getContext(Context).?);
            _ = context;
        }
    }

    fn inputEndedCallback(ipo: app.input.InputObject) void {
        // std.debug.print("input ended: {}\n", .{ipo});
        if (ipo.type == .mousebutton) {
            std.debug.print("mousebutton {} up\n", .{ipo.data.mousebutton});
        }
    }
};

pub fn checked_main(alloc: std.mem.Allocator) !void {
    var context = try Context.create(alloc);
    defer context.destroy();

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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var gpa_alloc = gpa.allocator();
    var alloc = gpa_alloc;

    try checked_main(alloc);
}

test {
    std.testing.refAllDecls(Renderer);
}
