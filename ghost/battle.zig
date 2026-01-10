const std = @import("std");
const zhu = @import("zhu");

pub const Stats = struct {
    health: u32 = 100, // 生命值
    maxHealth: u32 = 100, // 最大生命值
    attack: u32 = 40, // 攻击力
};
