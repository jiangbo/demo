const std = @import("std");
const zhu = @import("zhu");

const com = @import("component.zig");
const spawn = @import("spawn.zig");

pub const PlayerEnum = com.PlayerEnum;

/// 角色槽位数据
pub const Slot = struct {
    face: u32,
    class: PlayerEnum,
    cost: u8,
    rarity: u8,
    level: u8,
};

/// 从 context.zon 导入的数据类型
const SessionData = struct {
    level: u32,
    point: u32,
    units: []const struct {
        face: u32,
        class: PlayerEnum,
        level: u32,
        rarity: u32,
    },
};

const sessionData: SessionData = @import("zon/context.zon");

/// 根据 PlayerEnum 获取 cost（从 player.zon 读取）
fn getCost(class: PlayerEnum) u8 {
    return spawn.playerZon[@intFromEnum(class)].cost;
}

// --- 全局状态 ---

var gold: u32 = 50;
var selected: ?PlayerEnum = null;
var slots: [sessionData.units.len]Slot = undefined;

pub fn init() void {
    gold = 50;
    selected = null;

    for (&slots, sessionData.units) |*slot, unit| {
        slot.* = .{
            .face = unit.face,
            .class = unit.class,
            .cost = getCost(unit.class),
            .rarity = @intCast(unit.rarity),
            .level = @intCast(unit.level),
        };
    }

    // 按 cost 升序排序
    std.mem.sortUnstable(Slot, &slots, {}, struct {
        fn lessThan(_: void, a: Slot, b: Slot) bool {
            return a.cost < b.cost;
        }
    }.lessThan);
}

pub fn canAfford(class: PlayerEnum) bool {
    const cost = getCost(class);
    return gold >= cost;
}

pub fn spend(class: PlayerEnum) void {
    gold -= getCost(class);
}

pub fn getSelected() ?PlayerEnum {
    return selected;
}

pub fn setSelected(class: ?PlayerEnum) void {
    selected = class;
}

pub fn getGold() u32 {
    return gold;
}

pub fn getSlots() []const Slot {
    return &slots;
}
