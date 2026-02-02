const std = @import("std");
const zhu = @import("zhu");

pub const Image = zhu.graphics.Image;
pub const Sprite = struct {
    image: Image,
    offset: zhu.Vector2,
    flip: bool = false,
};
pub const Position = zhu.Vector2;
pub const Velocity = struct { v: zhu.Vector2 };
