const std = @import("std");

const app = @import("app/app.zig");
const math = @import("math.zig");

const RenderContext = @import("RenderContext.zig");

const image = @import("image.zig");

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
                .size = .{ 800, 800 },
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

        try self.render.load(self.allocator, self.window);

        var buffer: [1024]u8 = .{0} ** 1024;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const temp_allocator = fba.allocator();

        while (self.running()) {
            const frame = self.render.frame_arena.queryCapacity();
            const resource = self.render.resource_arena.queryCapacity();
            const permanent = self.render.permanent_arena.queryCapacity();
            const title = try std.fmt.allocPrint(
                temp_allocator,
                "{};{};{};{}",
                .{
                    frame,
                    resource,
                    permanent,
                    frame + resource + permanent,
                },
            );
            defer fba.reset();

            try self.pumpEvents();
            self.window.setTitle(title);

            const frame_start = std.time.nanoTimestamp();

            if (self.resized) |size| {
                try self.render.resize(size);
            }

            try self.render.draw();
            try self.render.present();

            const frame_end = std.time.nanoTimestamp();

            const frame_time = frame_end - frame_start;
            _ = frame_time;
            // std.debug.print("frame time: {d:1}\n", .{std.time.ns_per_s / @as(f64, @floatFromInt(frame_time))});

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

    image.setAllocator(alloc);

    // var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    // defer arena.deinit();
    // const alloc = arena.allocator();

    var context = try Context.init(alloc);
    defer context.deinit();

    try context.spawnWindowThread();

    // std.debug.print("mem: {}\n", .{arena.queryCapacity()});

    while (context.running()) {
        // if (std.time.timestamp() - start > 100) {
        //     start = std.time.timestamp();
        //     context.window.setVisible(!context.window.isVisible());
        // }
        std.time.sleep(std.time.ns_per_s);
    }

    // std.debug.print("mem: {}\n", .{arena.queryCapacity()});
}
