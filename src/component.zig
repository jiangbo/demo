const zhu = @import("zhu");

const factory = @import("factory.zig");

pub const Animation = zhu.Animation;

// 实体碰撞区域底边的中心位置。
pub const Position = zhu.Vector2;

// 实体当前面对的方向。
pub const Facing = enum { down, left, up, right };

pub fn oppositeFacing(facing: Facing) Facing {
    return switch (facing) {
        .down => .up,
        .left => .right,
        .up => .down,
        .right => .left,
    };
}

// 相对实体逻辑位置的碰撞区域。
pub const Collider = zhu.Rect;

// 图片相对实体逻辑位置的绘制偏移。
pub const RenderOffset = struct { value: zhu.Vector2 };

pub const Player = struct {};
// 实体对应的稳定人物标识。
pub const Actor = struct { key: factory.Key };
// 敌人相对实体逻辑位置的战斗触发区域。
pub const Enemy = struct { value: zhu.Rect };
// 可对话实体；Identity 指向当前对话对象。
pub const Talk = struct {};
pub const Wander = struct { value: zhu.Timer };

// 实体希望移动的单位方向。
pub const WantMove = struct { value: zhu.Vector2 };
pub const Speed = struct { value: f32 };
