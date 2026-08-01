const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("component.zig");
const zon = @import("zon.zig");

const Facing = component.actor.Facing;
const Player = component.actor.Player;
const Position = component.Position;
const Tip = component.event.Tip;

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

    // 使用当前经验升级，返回是否发生升级。
    pub fn levelUp(self: *Stats) bool {
        if (self.exp < 100) return false;

        const levelCount = self.exp / 100;
        self.level += levelCount;
        self.maxHealth += levelCount * 30;
        self.attack += levelCount;
        self.defend += levelCount;
        self.exp %= 100;
        self.health = self.maxHealth;
        return true;
    }
};

// 玩家已经越过的剧情进度。
pub const Progress = struct { value: u8 = 1 };

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

// 切换地图时保留的长期数据类型。
pub const keep = .{
    DeadActors,
    OpenedChests,
    Progress,
    Stats,
    Inventory,
};

// 存档中的当前地图和玩家位置。
pub const Location = struct {
    map: zon.Map.Key,
    position: zhu.Vector2,
    facing: Facing,
};

// ZON 存档的完整结构。
const Record = struct {
    location: Location,
    progress: Progress = .{},
    stats: Stats = .{},
    inventory: Inventory = .{},
    openedChests: OpenedChests = .empty,
    deadActors: DeadActors = .empty,
};

// 重置新游戏使用的长期状态。
pub fn reset(world: *ecs.World) void {
    world.addAll(world.entity, .{
        DeadActors.empty,
        OpenedChests.initEmpty(),
        Progress{},
        Stats{},
        Inventory{},
    });
}

// 检查指定槽位是否已有存档。
pub fn exists(slot: u8) bool {
    var buffer: [20]u8 = undefined;
    const path = zhu.formatZ(&buffer, "save/{d}.sav", .{slot});
    return zhu.window.exists(path);
}

// 读取存档并恢复跨地图长期状态。
pub fn load(world: *ecs.World, gpa: zhu.Allocator, slot: u8) ?Location {
    var buffer: [20]u8 = undefined;
    const path = zhu.formatZ(&buffer, "save/{d}.sav", .{slot});
    const source = zhu.window.readAll(gpa.raw, path) catch |err| {
        std.log.err("load {s} failed: {}", .{ path, err });
        return null;
    };
    defer gpa.free(source);
    crypt(source);

    var loaded = zhu.window.parseZon(Record, source, .{}) catch |err| {
        std.log.err("load {s} failed: {}", .{ path, err });
        return null;
    };
    defer loaded.deinit();

    const record = loaded.value;
    world.addAll(world.entity, .{
        record.progress,
        record.stats,
        record.inventory,
        record.openedChests,
        record.deadActors,
    });

    return record.location;
}

// 收集玩家位置和长期状态并写入存档。
pub fn save(world: *ecs.World, gpa: zhu.Allocator, slot: u8) void {
    const player = world.getIdentityEntity(Player).?;
    const record: Record = .{
        .location = .{
            .map = world.get(player, zon.Map.Key).?,
            .position = world.get(player, Position).?,
            .facing = world.get(player, Facing).?,
        },
        .progress = world.getGlobal(Progress).?.*,
        .stats = world.getGlobal(Stats).?.*,
        .inventory = world.getGlobal(Inventory).?.*,
        .openedChests = world.getGlobal(OpenedChests).?.*,
        .deadActors = world.getGlobal(DeadActors).?.*,
    };
    var buffer: [20]u8 = undefined;
    const path = zhu.formatZ(&buffer, "save/{d}.sav", .{slot});
    const content = zhu.window.allocZon(gpa.raw, record) catch |err| {
        std.log.err("save {s} failed: {}", .{ path, err });
        world.addEvent(Tip{ .text = "保存失败" });
        return;
    };
    defer gpa.free(content);
    crypt(content);

    zhu.window.saveAll(path, content) catch |err| {
        std.log.err("save {s} failed: {}", .{ path, err });
        world.addEvent(Tip{ .text = "保存失败" });
    };
}

// 使用固定参数隐藏存档文本，同一操作同时用于加密和解密。
fn crypt(data: []u8) void {
    const xor = std.crypto.stream.chacha.ChaCha20IETF.xor;
    const key = "ShengJianYingXiongZhuanSaveKey!!".*;
    xor(data, data, 0, key, "SaveDataDemo".*);
}
