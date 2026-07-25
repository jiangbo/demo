const zhu = @import("zhu");

const zon = @import("zon.zig");

pub const Animation = zhu.Animation;

// 实体碰撞区域底边的中心位置。
pub const Position = zhu.Vector2;

// 实体当前面对的方向。
pub const Facing = zon.Facing;

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
pub const Actor = struct { key: zon.Key };
// 敌人相对实体逻辑位置的战斗触发区域。
pub const Enemy = struct {
    value: zhu.Rect,
    // 逃跑后暂时停止触发战斗。
    wait: f32 = 0,
};
// 可交互实体；Identity 指向当前交互对象。
pub const Interact = struct {
    // 暂时禁止产生新的交互对象。
    pub const Disabled = struct {};
};
pub const dialog = struct {
    // 由对话系统处理的可交互实体。
    pub const Talk = struct { dialogues: []const u16 };

    pub const Value = union(enum) { number: u32, text: []const u8 };

    // 当前活动的对话，挂在 world.entity 上。
    pub const Dialog = struct {
        lines: []const zon.dialog.Line,
        // 当前显示行。
        line: usize = 0,
        // UI 当前绘制的文本。
        text: ?[]const u8 = null,
        value: ?Value = null,
    };
};
pub const Wander = struct { value: zhu.Timer };

// 实体希望移动的单位方向。
pub const WantMove = struct { value: zhu.Vector2 };
pub const Speed = struct { value: f32 };
