const std = @import("std");
const zhu = @import("zhu");

pub const Position = zhu.Vector2;

pub const Velocity = struct { value: zhu.Vector2 = .zero };

pub const Collider = struct {
    size: zhu.Vector2,
    offset: zhu.Vector2 = .zero,
};

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
pub const Facing = enum { down, up, left, right };
pub const Actor = struct {
    animation: PlayerAnimation = .idle,
    facing: Facing = .down,
    rows: [4]i8 = .{ 0, 1, -2, 2 },
};
pub const GrowthEnum = enum { seed, sprout, growing, mature };

pub const Crop = struct {
    stage: GrowthEnum = .seed,
    timer: f32 = 0,
    next: f32 = 0,
    watered: bool = false,
};

pub const Target = struct {
    position: zhu.Vector2 = .zero,
    color: zhu.Color = .rgba(0, 1, 0, 0.2),
    active: bool = false,
};

pub const ItemEnum = enum { hoe, water, seed, crop };
pub const Pickup = struct { item: ItemEnum, count: u32 = 1 };
