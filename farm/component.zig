const zhu = @import("zhu");

pub const Position = zhu.Vector2;

pub const Sprite = struct {
    image: zhu.graphics.Image,
    offset: zhu.Vector2 = .zero,
    size: ?zhu.Vector2 = null,
    flip: bool = false,
};

pub const Player = struct {};
pub const Crop = struct {
    growth: f32 = 0,
};
pub const Farmland = struct {
    watered: bool = false,
};
