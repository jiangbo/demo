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

pub const Path = struct {
    point: zhu.Vector2, // 路径点位置
    next: u8 = 0, // 终点没有下一个路径点
    next2: u8 = 0, // 可选的第二条分支路径

    pub fn randomNext(self: Path) u8 {
        if (self.next2 == 0) return self.next;
        return if (zhu.randomBool()) self.next else self.next2;
    }
};

pub const Enemy = struct { target: Path, speed: f32 };
pub const Face = enum { Left, Right };
pub const Blocker = struct { max: u8, current: u8 = 0 };
pub const BlockBy = struct { entity: zhu.ecs.Entity };
