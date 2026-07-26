const std = @import("std");
const zhu = @import("zhu");

const zon = @import("zon.zig");

// 已经死亡、地图重建后不再创建的 NPC。
pub const DeadActors = std.EnumSet(zon.Actor.Key);

// 切换地图时保留的长期数据类型。
pub const keep = .{
    DeadActors,
};

// 玩家在 ZON 存档中的数据。
pub const Player = struct {
    progress: u8 = 1,
    position: zhu.Vector2 = .zero,
    exp: u16 = 0,
    level: u16 = 1,
    health: u16 = 50,
    maxHealth: u16 = 50,
    attack: u16 = 10,
    defend: u16 = 10,
    speed: u16 = 8,
    money: u32 = 50,
    items: [16]u8 = @splat(0),
};

// ZON 存档的完整结构。
pub const Record = struct {
    portal: zon.Portal.Key = .start,
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
