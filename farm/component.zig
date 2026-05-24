const std = @import("std");
const zhu = @import("zhu");

pub const Position = zhu.Vector2;

pub const motion = struct {
    pub const Velocity = struct { value: zhu.Vector2 = .zero };

    pub const Collider = struct {
        size: zhu.Vector2,
        offset: zhu.Vector2 = .zero,
    };
};

pub const render = struct {
    pub const Sprite = struct {
        image: zhu.graphics.Image,
        offset: zhu.Vector2 = .zero,
        size: ?zhu.Vector2 = null,
        flip: bool = false,
    };

    pub const Layer = enum(i16) {
        ground = 0,
        crop = 10,
        actor = 20,
    };

    pub const Render = struct {
        layer: Layer = .actor,
        depth: f32 = 0,
        color: zhu.Color = .white,
    };

    pub const YSort = struct {};
};

pub const map = struct {
    pub const Id = enum { school, town };
    pub const StartOffset = enum { none, left, right, top, bottom };

    pub const Scoped = struct {};

    pub const Trigger = struct {
        rect: zhu.Rect,
        selfId: i32,
        targetId: i32,
        targetMap: Id,
        startOffset: StartOffset,
    };
};

pub const actor = struct {
    pub const AnimalKind = enum { cow, sheep };

    pub const Action = enum {
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
    pub const Npc = struct {};
    pub const Animal = struct { kind: AnimalKind };
    pub const Facing = enum { down, up, left, right };
    pub const Actor = struct {
        action: Action = .idle,
        facing: Facing = .down,
        rows: [4]i8 = .{ 1, 2, -3, 3 },
    };

    pub const Wander = struct {
        home: zhu.Vector2 = .zero,
        radius: f32 = 0,
        speed: f32 = 0,
        target: zhu.Vector2 = .zero,
        waitTimer: f32 = 0,
        moving: bool = false,
        minWait: f32 = 0.6,
        maxWait: f32 = 1.8,
        lastDistance2: f32 = 0,
        stuckTimer: f32 = 0,
        stuckReset: f32 = 1.0,
    };
};

pub const farm = struct {
    pub const GrowthEnum = enum { seed, sprout, growing, mature };

    pub const Crop = struct {
        stage: GrowthEnum = .seed,
        timer: f32 = 0,
        next: f32 = 0,
        watered: bool = false,
    };
};

pub const ui = struct {
    pub const Target = struct {
        position: zhu.Vector2 = .zero,
        color: zhu.Color = .rgba(0, 1, 0, 0.2),
        active: bool = false,
    };
};

pub const item = struct {
    pub const ItemEnum = enum { hoe, water, seed, crop };
    pub const Pickup = struct { item: ItemEnum, count: u32 = 1 };
};
