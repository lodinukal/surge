pub const Point = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Point {
        return Point{ .x = x, .y = y };
    }

    pub fn eql(p: Point, other: Point) bool {
        return p.x == other.x and p.y == other.y;
    }

    pub fn getEnclosingRect(points: []Point, clipping: Rect) ?Rect {
        if (points.len == 0) {
            return null;
        }

        var min = points[0];
        var max = points[0];
        for (points) |p| {
            if (p.x < min.x) {
                min.x = p.x;
            }
            if (p.y < min.y) {
                min.y = p.y;
            }
            if (p.x > max.x) {
                max.x = p.x;
            }
            if (p.y > max.y) {
                max.y = p.y;
            }
        }

        const rect = Rect.fromMinMax(min, max);
        if (rect.getIntersection(clipping)) |intersection| {
            return intersection;
        }
        return null;
    }
};

pub const FPoint = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) FPoint {
        return FPoint{ .x = x, .y = y };
    }

    pub fn eql(p: FPoint, other: FPoint) bool {
        return p.x == other.x and p.y == other.y;
    }

    pub fn getEnclosingRect(points: []FPoint, clipping: FRect) ?FRect {
        if (points.len == 0) {
            return null;
        }

        var min = points[0];
        var max = points[0];
        for (points) |p| {
            if (p.x < min.x) {
                min.x = p.x;
            }
            if (p.y < min.y) {
                min.y = p.y;
            }
            if (p.x > max.x) {
                max.x = p.x;
            }
            if (p.y > max.y) {
                max.y = p.y;
            }
        }

        const rect = FRect.fromMinMax(min, max);
        if (rect.getIntersection(clipping)) |intersection| {
            return intersection;
        }
        return null;
    }
};

pub const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn init(x: i32, y: i32, w: i32, h: i32) Rect {
        return Rect{ .x = x, .y = y, .w = w, .h = h };
    }

    pub fn fromMinMax(min: Point, max: Point) Rect {
        return Rect{ .x = min.x, .y = min.y, .w = max.x - min.x, .h = max.y - min.y };
    }

    pub fn hasPoint(rect: Rect, p: Point) bool {
        return p.x >= rect.x and
            p.x < rect.x + rect.w and
            p.y >= rect.y and
            p.y < rect.y + rect.h;
    }

    pub fn isEmpty(rect: Rect) bool {
        return rect.w == 0 or rect.h == 0;
    }

    pub fn eql(rect: Rect, other: Rect) bool {
        return rect.x == other.x and
            rect.y == other.y and
            rect.w == other.w and
            rect.h == other.h;
    }

    pub fn intersects(rect: Rect, other: Rect) bool {
        return rect.x < other.x + other.w and
            rect.x + rect.w > other.x and
            rect.y < other.y + other.h and
            rect.y + rect.h > other.y;
    }

    pub fn getIntersection(rect: Rect, other: Rect) ?Rect {
        if (!rect.intersects(other)) {
            return null;
        }

        const x1 = @max(rect.x, other.x);
        const y1 = @max(rect.y, other.y);
        const x2 = @min(rect.x + rect.w, other.x + other.w);
        const y2 = @min(rect.y + rect.h, other.y + other.h);
        return Rect{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }

    pub fn getUnion(rect: Rect, other: Rect) Rect {
        const x1 = @min(rect.x, other.x);
        const y1 = @min(rect.y, other.y);
        const x2 = @max(rect.x + rect.w, other.x + other.w);
        const y2 = @max(rect.y + rect.h, other.y + other.h);
        return Rect{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }

    pub fn intersectsLine(rect: Rect, p1: Point, p2: Point) bool {
        if (rect.hasPoint(p1) or rect.hasPoint(p2)) {
            return true;
        }

        const left = rect.x;
        const right = rect.x + rect.w;
        const top = rect.y;
        const bottom = rect.y + rect.h;

        const m = @divTrunc(p2.y - p1.y, p2.x - p1.x);
        const b = p1.y - m * p1.x;

        const y1 = m * left + b;
        const y2 = m * right + b;
        const x1 = @divTrunc(top - b, m);
        const x2 = @divTrunc(bottom - b, m);

        return (y1 >= top and y1 <= bottom) or
            (y2 >= top and y2 <= bottom) or
            (x1 >= left and x1 <= right) or
            (x2 >= left and x2 <= right);
    }
};

pub const FRect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,

    pub fn init(x: f32, y: f32, w: f32, h: f32) FRect {
        return FRect{ .x = x, .y = y, .w = w, .h = h };
    }

    pub fn fromMinMax(min: FPoint, max: FPoint) FRect {
        return FRect{ .x = min.x, .y = min.y, .w = max.x - min.x, .h = max.y - min.y };
    }

    pub fn hasPoint(rect: FRect, p: FPoint) bool {
        return p.x >= rect.x and
            p.x < rect.x + rect.w and
            p.y >= rect.y and
            p.y < rect.y + rect.h;
    }

    pub fn isEmpty(rect: FRect) bool {
        return rect.w == 0 or rect.h == 0;
    }

    pub fn eql(rect: FRect, other: FRect) bool {
        return rect.x == other.x and
            rect.y == other.y and
            rect.w == other.w and
            rect.h == other.h;
    }

    pub fn intersects(rect: FRect, other: FRect) bool {
        return rect.x < other.x + other.w and
            rect.x + rect.w > other.x and
            rect.y < other.y + other.h and
            rect.y + rect.h > other.y;
    }

    pub fn getIntersection(rect: FRect, other: FRect) ?FRect {
        if (!rect.intersects(other)) {
            return null;
        }

        const x1 = @max(rect.x, other.x);
        const y1 = @max(rect.y, other.y);
        const x2 = @min(rect.x + rect.w, other.x + other.w);
        const y2 = @min(rect.y + rect.h, other.y + other.h);
        return FRect{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }

    pub fn getUnion(rect: FRect, other: FRect) FRect {
        const x1 = @min(rect.x, other.x);
        const y1 = @min(rect.y, other.y);
        const x2 = @max(rect.x + rect.w, other.x + other.w);
        const y2 = @max(rect.y + rect.h, other.y + other.h);
        return FRect{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }

    pub fn intersectsLine(rect: FRect, p1: FPoint, p2: FPoint) bool {
        if (rect.hasPoint(p1) or rect.hasPoint(p2)) {
            return true;
        }

        const left = rect.x;
        const right = rect.x + rect.w;
        const top = rect.y;
        const bottom = rect.y + rect.h;

        const m = (p2.y - p1.y) / (p2.x - p1.x);
        const b = p1.y - m * p1.x;

        const y1 = m * left + b;
        const y2 = m * right + b;
        const x1 = (top - b) / m;
        const x2 = (bottom - b) / m;

        return (y1 >= top and y1 <= bottom) or
            (y2 >= top and y2 <= bottom) or
            (x1 >= left and x1 <= right) or
            (x2 >= left and x2 <= right);
    }
};

const std = @import("std");
test "ref" {
    std.testing.refAllDeclsRecursive(@This());
}
