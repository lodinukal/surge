const std = @import("std");
const gpu = @import("gpu");

const math = @import("core").math;

const Self = @This();

projection: math.Mat = math.identity(),
view: math.Mat = math.identity(),

pub fn setOrthoProjection(self: *Self, left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) void {
    self.projection = math.orthographicOffCenterLh(left, right, top, bottom, near, far);
}

pub fn setPerspectiveProjection(self: *Self, fov: f32, aspect: f32, near: f32, far: f32) void {
    self.projection = math.perspectiveFovLh(fov, aspect, near, far);
}

pub fn setViewDirection(self: *Self, eye: math.Vec, direction: math.Vec, up: math.Vec) void {
    self.view = math.lookToLh(eye, direction, up);
}

pub fn setViewPosDir(self: *Self, position: math.Vec, rotation: math.Vec) void {
    self.view = math.identity();
    self.view = math.mul(self.view, rotation.x, math.vec3(1, 0, 0));
    self.view = math.mul(self.view, rotation.y, math.vec3(0, 1, 0));
    self.view = math.mul(self.view, rotation.z, math.vec3(0, 0, 1));
    self.view = math.translationV(self.view, position);
}
