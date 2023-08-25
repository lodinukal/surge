const std = @import("std");

const SPIN_LIMIT: u32 = 6;
const YIELD_LIMIT: u32 = 10;

pub const Backoff = struct {
    step: u32,

    pub inline fn init() Backoff {
        return Backoff{ .step = 0 };
    }

    pub inline fn reset(b: *Backoff) void {
        b.step = 0;
    }

    pub inline fn spin(b: *Backoff) void {
        for (0..(1 << @min(b.step, SPIN_LIMIT))) |_| {
            std.atomic.spinLoopHint();
        }

        if (b.step < SPIN_LIMIT) {
            b.step += 1;
        }
    }

    pub inline fn snooze(b: *Backoff) void {
        if (b.step <= SPIN_LIMIT) {
            for (0..(1 << b.step)) |_| {
                std.atomic.spinLoopHint();
            }
        } else {
            for (0..(1 << b.step)) |_| {
                std.atomic.spinLoopHint();
            }
            _ = try std.Thread.yield();
        }

        if (b.step <= YIELD_LIMIT) {
            b.step += 1;
        }
    }

    pub inline fn isCompleted(b: *Backoff) bool {
        return b.step > YIELD_LIMIT;
    }
};
