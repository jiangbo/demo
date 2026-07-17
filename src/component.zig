const zhu = @import("zhu");

const Direction = @import("context.zig").Direction;

pub const Animation = zhu.Animation;

// 地图角色的位置和朝向。
pub const Actor = struct {
    // 角色图片底边的中心位置。
    position: zhu.Vector2,
    facing: Direction,
};

pub const Collider = struct {
    size: zhu.Vector2,

    // 根据角色底边中心计算碰撞区域。
    pub fn rect(self: Collider, position: zhu.Vector2) zhu.Rect {
        const min = position.addXY(-self.size.x * 0.5, -self.size.y);
        return .init(min, self.size);
    }
};

pub const Npc = struct { index: u8 };
pub const Timer = struct { value: zhu.Timer };
