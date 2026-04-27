const std = @import("std");
const zhu = @import("zhu");

const com = @import("component.zig");
const spawn = @import("spawn.zig");

pub const PlayerEnum = com.PlayerEnum;

/// 角色槽位数据
pub const Unit = struct {
    name: [:0]const u8,
    face: u32,
    class: PlayerEnum,
    level: f32,
    rarity: f32,
    position: zhu.Vector2 = .zero,
    cost: f32 = 0,
};

const ContextZon = struct {
    level: u32,
    point: u32,
    units: []const Unit,
};

const contextZon: ContextZon = @import("zon/context.zon");
const INITIAL_COST: f32 = 10; // 初始 COST
const COST_GEN_PER_SECOND: f32 = 1; // 每秒恢复的 COST
const INITIAL_HOME_HEALTH: i32 = 5; // 初始基地生命值

// --- 全局状态 ---

pub var cost: f32 = INITIAL_COST;
pub var homeHealth: i32 = INITIAL_HOME_HEALTH;
pub var enemyCount: u32 = 0;
pub var enemyArrivedCount: u32 = 0;
pub var enemyKilledCount: u32 = 0;
pub var selected: ?usize = null;
pub var hoveredEntity: ?zhu.ecs.Entity = null;
pub var selectedEntity: ?zhu.ecs.Entity = null;
pub var uiWantCaptureMouse: bool = false;
pub var units: std.ArrayList(Unit) = .empty;
pub var unitLayoutDirty: bool = true;
// ZON 中的关卡从 1 开始，代码中统一使用 0-based 索引。
pub var levelIndex: usize = 0;

pub fn init() void {
    if (contextZon.level == 0) @panic("level must start at 1");
    levelIndex = @intCast(contextZon.level - 1);

    for (contextZon.units) |zon| {
        var unit = zon;
        const base = spawn.playerZon[@intFromEnum(unit.class)].cost;
        const levelScale = 0.95 + 0.05 * unit.level;
        const rarityScale = 0.9 + 0.1 * unit.rarity;
        unit.cost = @round(base * levelScale * rarityScale);
        units.append(zhu.assets.allocator, unit) catch @panic("oom, can't append unit");
    }

    // 按 cost 升序排序
    std.mem.sortUnstable(Unit, units.items, {}, struct {
        fn lessThan(_: void, a: Unit, b: Unit) bool {
            return a.cost < b.cost;
        }
    }.lessThan);
}

pub fn deinit() void {
    units.deinit(zhu.assets.allocator);
}

pub fn update(delta: f32) void {
    cost += COST_GEN_PER_SECOND * delta;
}

pub fn selectedUnit() ?Unit {
    return if (selected) |index| units.items[index] else null;
}

pub fn spendSelected() void {
    const index = selected.?;
    cost -= units.items[index].cost;
    _ = units.orderedRemove(index);
    selected = null;
    unitLayoutDirty = true;
}

pub fn isGameOver() bool {
    return homeHealth <= 0;
}

pub fn isLevelClear() bool {
    return enemyCount > 0 and
        enemyKilledCount + enemyArrivedCount >= enemyCount;
}
