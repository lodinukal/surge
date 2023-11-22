const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");
const Renderer = @import("render/gpu/Renderer.zig");

const interface = @import("core/interface.zig");

const Context = struct {
    allocator: std.mem.Allocator = undefined,
    application: *app.Application = undefined,
    window: *app.window.Window = undefined,

    ui_thread: ?std.Thread = null,
    mutex: std.Thread.Mutex = .{},
    ready: bool = false,

    renderer: *Renderer = undefined,
    swapchain: Renderer.Handle(Renderer.SwapChain) = undefined,
    resized_size: ?[2]u32 = null,

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

        self.renderer = try Renderer.create(self.allocator, .{});
        errdefer self.renderer.destroy();
        try self.renderer.load(.d3d11);

        // application.input.focused_changed_callback = focused_changed_callback;
        self.application.input.input_began_callback = inputBeganCallback;
        self.application.input.input_changed_callback = inputChangedCallback;
        self.application.input.input_ended_callback = inputEndedCallback;
        self.application.input.frame_update_callback = frameUpdate;

        self.window = try self.application.createWindow(.{
            .title = "helloo!",
            .size = .{ 800, 600 },
            .visible = true,
        });
        self.window.storeContext(Context, self);
    }

    fn deinit(self: *Context) void {
        self.renderer.destroySwapchain(self.swapchain) catch {};
        self.renderer.destroy();

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
    }

    pub const focused_sleep = std.time.ns_per_us * 100;
    pub const unfocused_sleep = std.time.ns_per_ms * 10;

    fn windowLoop(self: *Context) !void {
        try self.window.build();
        self.swapchain = try self.renderer.createSwapchain(&.{
            .resolution = .{ 800, 600 },
        }, self.window);

        while (self.running()) {
            try self.pumpEvents();
            var char_buffer: [256]u8 = undefined;
            if (self.window.getPosition()) |pos| {
                const res = try std.fmt.bufPrint(&char_buffer, "{}x{}", .{ pos[0], pos[1] });
                self.window.setTitle(res);
            }
            std.time.sleep(if (self.window.isFocused()) focused_sleep else unfocused_sleep);

            var renderer = self.renderer;
            var swapchain = renderer.useSwapchainMutable(self.swapchain) catch return;
            if (self.resized_size) |size| {
                swapchain.resizeBuffers(
                    .{
                        @intCast(size[0]),
                        @intCast(size[1]),
                    },
                    .{
                        .modify_surface = true,
                        .fullscreen = self.window.getFullscreenMode() == .fullscreen,
                    },
                ) catch return;
            }
            swapchain.present();

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
            var context = ipo.window.?.getContext(Context).?;
            context.resized_size = .{ @intCast(ipo.data.resize[0]), @intCast(ipo.data.resize[1]) };
        }
    }

    fn inputEndedCallback(ipo: app.input.InputObject) void {
        // std.debug.print("input ended: {}\n", .{ipo});
        if (ipo.type == .mousebutton) {
            std.debug.print("mousebutton {} up\n", .{ipo.data.mousebutton});
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var gpa_alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    var alloc = arena.allocator();

    var context = try Context.create(alloc);
    defer context.destroy();

    try context.spawnWindowThread();

    std.debug.print("mem: {}\n", .{arena.queryCapacity()});

    var start = std.time.timestamp();
    while (context.running()) {
        if (std.time.timestamp() - start > 100) {
            start = std.time.timestamp();
            context.window.setVisible(!context.window.isVisible());
        }
        std.time.sleep(std.time.ns_per_s);
    }

    std.debug.print("mem: {}\n", .{arena.queryCapacity()});
}

test {
    std.testing.refAllDecls(Renderer);
}
