const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");
const Renderer = @import("render/gpu/Renderer.zig");

const interface = @import("core/interface.zig");

const Context = struct {
    allocator: std.mem.Allocator,
    application: *app.Application,
    window: *app.window.Window,
    // renderer: *app.renderer.Renderer,

    ui_thread: ?std.Thread = null,
    mutex: std.Thread.Mutex = .{},
    ready: bool = false,

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
            }),
        };
    }

    pub fn deinit(self: *Context) void {
        if (self.ui_thread) |t| {
            t.join();
        }
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
        defer self.window.destroy();
        while (self.running()) {
            try self.pumpEvents();
            var char_buffer: [256]u8 = undefined;
            const pos = self.window.getPosition();
            const res = try std.fmt.bufPrint(&char_buffer, "{}x{}", .{ pos.?[0], pos.?[1] });
            self.window.setTitle(res);
            std.time.sleep(if (self.window.isFocused()) focused_sleep else unfocused_sleep);
        }
    }

    fn frameUpdate(wnd: *app.window.Window) void {
        _ = wnd;
        std.debug.print("update: {}\n", .{1});
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
            std.debug.print("resize: {}x{}\n", .{ ipo.data.resize[0], ipo.data.resize[1] });
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

    var context = try Context.init(alloc);
    defer context.deinit();

    var renderer = try Renderer.create(alloc, .{});
    defer renderer.destroy();
    try renderer.load(.d3d11);

    const sw = try renderer.createSwapchain(&.{
        .resolution = .{ 800, 600 },
    }, context.window);
    defer renderer.destroySwapchain(sw) catch {};

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
