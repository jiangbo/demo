const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const zon = @import("zon.zig");

// 已经死亡、地图重建后不再创建的 NPC。
pub const DeadActors = std.EnumSet(zon.Actor.Key);

// 已经开启、地图重建后保持开启的宝箱。
pub const OpenedChests = std.StaticBitSet(zon.Chest.list.len);

// 玩家参与战斗和成长的数值。
pub const Stats = struct {
    level: u16 = 1, // 等级
    exp: u16 = 0, // 经验
    health: u16 = 50, // 生命
    maxHealth: u16 = 50, // 最大生命
    attack: u16 = 10, // 攻击
    defend: u16 = 10, // 防御
    agility: u16 = 8, // 敏捷
};

// 玩家持有的金钱和物品。
pub const Inventory = struct {
    money: u32 = 50, // 金钱
    items: [16]?zon.Item.Key = @splat(null), // 物品

    // 将物品放入第一个空位。
    pub fn add(self: *Inventory, key: zon.Item.Key) bool {
        for (&self.items) |*value| {
            if (value.* != null) continue;
            value.* = key;
            return true;
        }
        return false;
    }
};

// 玩家跨地图和战斗长期保留的数据。
pub const Player = struct {
    progress: u8 = 1, // 剧情进度
    stats: Stats = .{},
    inventory: Inventory = .{},
};

// 切换地图时保留的长期数据类型。
pub const keep = .{
    DeadActors,
    OpenedChests,
    Player,
};

// ZON 存档的完整结构。
pub const Record = struct {
    portal: zon.Portal.Key = .start,
    position: zhu.Vector2 = .zero,
    facing: component.actor.Facing = .down,
    player: Player = .{},
    openedChests: []const u16 = &.{},
    deadActors: []const zon.Actor.Key = &.{},
};

pub fn read(index: u8) !zhu.window.Zon(Record) {
    var buffer: [20]u8 = undefined;
    const path = zhu.formatZ(&buffer, "save/{d}.zon", .{index - 2});
    return zhu.window.readZon(Record, path, .{});
}

pub fn write(index: u8, record: Record) !void {
    var buffer: [20]u8 = undefined;
    const path = zhu.formatZ(&buffer, "save/{d}.zon", .{index - 2});
    try zhu.window.saveZon(path, record);
}
