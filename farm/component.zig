const zhu = @import("zhu");

pub const Position = zhu.Vector2;

pub const Velocity = struct { value: zhu.Vector2 = .zero };

pub const Sprite = struct {
    image: zhu.graphics.Image,
    offset: zhu.Vector2 = .zero,
    size: ?zhu.Vector2 = null,
    flip: bool = false,
};

pub const RenderLayer = enum(i16) {
    ground = 0,
    crop = 10,
    actor = 20,
};

pub const Render = struct {
    layer: RenderLayer = .actor,
    depth: f32 = 0,
    color: zhu.Color = .white,
};

pub const YSort = struct {};

pub const PlayerAnimation = enum {
    idle, // 待机
    walk, // 行走
    hoe, // 锄地
    watering, // 浇水
    planting, // 播种
    sickle, // 镰刀
    axe, // 斧头
    pickaxe, // 镐头
};

pub const Animation = zhu.graphics.Animation;

pub const Player = struct {};
pub const Crop = struct {
    growth: f32 = 0,
};
pub const Farmland = struct {
    watered: bool = false,
};
