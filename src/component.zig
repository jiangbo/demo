const zhu = @import("zhu");

pub const Animation = zhu.Animation;

// 实体图片底边的中心位置。
pub const Position = zhu.Vector2;

// 实体当前面对的方向。
pub const Facing = enum { down, left, up, right };

pub const Collider = struct {
    size: zhu.Vector2,
    offset: zhu.Vector2 = .zero,

    // 根据角色底边中心计算碰撞区域。
    pub fn rect(self: Collider, entityPosition: zhu.Vector2) zhu.Rect {
        const center = entityPosition.add(self.offset);
        const min = center.addXY(-self.size.x * 0.5, -self.size.y);
        return .init(min, self.size);
    }

    // 根据碰撞区域左上角计算角色底边中心。
    pub fn position(self: Collider, min: zhu.Vector2) zhu.Vector2 {
        const center = min.addXY(self.size.x * 0.5, self.size.y);
        return center.sub(self.offset);
    }
};

pub const Player = struct {};
pub const Npc = struct { index: u8 };
pub const Wander = struct { value: zhu.Timer };

// 实体希望移动的单位方向。
pub const WantMove = struct { value: zhu.Vector2 };
pub const Speed = struct { value: f32 };
