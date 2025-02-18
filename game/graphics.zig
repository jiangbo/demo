const std = @import("std");
const zm = @import("zmath");

pub const Camera = struct {
    view: zm.Mat,
    proj: zm.Mat,

    pub fn init(width: f32, height: f32) Camera {
        return .{
            .view = zm.lookAtLh(
                zm.f32x4(0, 0, 0, 0), // 眼睛所在位置
                zm.f32x4(0, 0, 1, 0), // 眼睛看向的位置
                zm.f32x4(0, 1, 0, 0), // 头顶方向
            ),
            .proj = zm.orthographicOffCenterLh(0, width, 0, height, 0, 1),
        };
    }

    pub fn vp(self: Camera) zm.Mat {
        return zm.mul(self.view, self.proj);
    }
};
