const std = @import("std");
const definitions = @import("definitions.zig");

pub const MonitorConnectionCallback = ?*fn (monitor: Monitor, connected: bool) void;

pub fn getMonitors() []const definitions.Monitor {}

pub fn getPrimaryMonitor() definitions.Monitor {}

pub const Monitor = struct {
    pub fn getPos(m: *Monitor) definitions.Error!struct {
        x: i32,
        y: i32,
    } {
        _ = m;
    }

    pub fn getWorkArea(m: *Monitor) definitions.Error!struct {
        x: i32,
        y: i32,
        width: u32,
        height: u32,
    } {
        _ = m;
    }

    pub fn getPhysicalSize(m: *Monitor) definitions.Error!struct {
        width_mm: u32,
        height_mm: u32,
    } {
        _ = m;
    }

    pub fn getContentScale(m: *Monitor) definitions.Error!struct {
        x: f32,
        y: f32,
    } {
        _ = m;
    }

    pub fn getName(
        m: *Monitor,
        allocator: std.mem.Allocator,
    ) (definitions.Error | std.mem.Allocator.Error)![]const u8 {
        _ = m;
        _ = allocator;
    }

    pub fn setUserPointer(
        m: *Monitor,
        pointer: ?*void,
    ) definitions.Error!void {
        _ = m;
        _ = pointer;
    }

    pub fn getUserPointer(m: *Monitor) definitions.Error!?*void {
        _ = m;
        return null;
    }

    pub fn setConnectionCallback(
        callback: ?MonitorConnectionCallback,
    ) definitions.Error!?MonitorConnectionCallback {
        _ = callback;
    }

    pub fn getVideoModes(
        m: *Monitor,
        allocator: std.mem.Allocator,
    ) (std.mem.Allocator.Error | definitions.Error)![]const definitions.VideoMode {
        _ = allocator;
        _ = m;
    }

    pub fn setGamma(
        m: *Monitor,
        gamma: f32,
    ) definitions.Error!void {
        _ = m;
        _ = gamma;
    }

    pub fn getGammaRamp(
        m: *Monitor,
        allocator: std.mem.Allocator,
    ) (std.mem.Allocator.Error | definitions.Error)!*const definitions.GammaRamp {
        _ = allocator;
        _ = m;
    }

    pub fn setGammaRamp(
        m: *Monitor,
        ramp: *const definitions.GammaRamp,
    ) definitions.Error!void {
        _ = m;
        _ = ramp;
    }
};
