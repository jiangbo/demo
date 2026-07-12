const std = @import("std");
const zhu = @import("zhu");

pub var battleNpcIndex: u16 = 0;
pub var oldMapIndex: u8 = 0;

pub const Direction = enum {
    down,
    left,
    up,
    right,

    pub fn random() Direction {
        return @enumFromInt(zhu.random.int(u8, 0, 4));
    }

    pub fn opposite(self: Direction) Direction {
        return switch (self) {
            .down => .up,
            .left => .right,
            .up => .down,
            .right => .left,
        };
    }
};
