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
const INITIAL_COST: f32 = 10; // 初始 COST
const COST_GEN_PER_SECOND: f32 = 1; // 每秒恢复的 COST
const INITIAL_HOME_HEALTH: i32 = 5; // 初始基地生命值

fn playerCost(class: PlayerEnum) u8 {
    return spawn.playerZon[@intFromEnum(class)].cost;
}

// --- 全局状态 ---

pub var cost: f32 = INITIAL_COST;
pub var homeHealth: i32 = INITIAL_HOME_HEALTH;
pub var enemyCount: u32 = 0;
pub var enemyArrivedCount: u32 = 0;
pub var enemyKilledCount: u32 = 0;
var selected: ?PlayerEnum = null;
var slots: [sessionData.units.len]Slot = undefined;

pub fn init() void {
    cost = INITIAL_COST;
    homeHealth = INITIAL_HOME_HEALTH;
    enemyCount = 0;
    enemyArrivedCount = 0;
    enemyKilledCount = 0;
    selected = null;

    for (&slots, sessionData.units) |*slot, unit| {
        slot.* = .{
            .face = unit.face,
            .class = unit.class,
            .cost = playerCost(unit.class),
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

pub fn update(delta: f32) void {
    cost += COST_GEN_PER_SECOND * delta;
}

pub fn canAfford(class: PlayerEnum) bool {
    return canAffordCost(playerCost(class));
}

pub fn spend(class: PlayerEnum) void {
    spendCost(playerCost(class));
}

pub fn canAffordCost(value: u8) bool {
    return cost >= @as(f32, @floatFromInt(value));
}

pub fn spendCost(value: u8) void {
    if (!canAffordCost(value)) return;
    cost -= @floatFromInt(value);
}

pub fn getSelected() ?PlayerEnum {
    return selected;
}

pub fn setSelected(class: ?PlayerEnum) void {
    selected = class;
}

pub fn isGameOver() bool {
    return homeHealth <= 0;
}

pub fn isLevelClear() bool {
    return enemyCount > 0 and
        enemyKilledCount + enemyArrivedCount >= enemyCount;
}

pub fn getSlots() []const Slot {
    return &slots;
}
