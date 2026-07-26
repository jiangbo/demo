const std = @import("std");
const zhu = @import("zhu");

const Animation = zhu.Animation;
const tiled = zhu.extend.tiled;

const NpcAnimation = struct {
    images: [15]zhu.graphics.ImageId,
    size: zhu.Vector2,
    frames: [4]Animation.Frames,
};

const Factory = struct {
    player: []const Animation.Source,
    bomb: []const Animation.Source,
    npc: NpcAnimation,
};

pub const Facing = enum { down, left, up, right };

pub const Actor = struct {
    key: [:0]const u8,
    enemy: bool = false,
    dialogues: ?[2]u16 = null,
    name: []const u8 = &.{},
    x: f32 = 0,
    y: f32 = 0,
    picture: u8 = 0,
    facing: Facing = .down,
    level: u16 = 1,
    health: u16 = 0,
    attack: u16 = 0,
    defend: u16 = 0,
    speed: f32 = 0,
    panicSpeed: ?f32 = null, // 慌乱时的移动速度
    goods: []const u8 = &.{},
    money: u16 = 0,
    progress: u8 = 0xFF,
    escape: u8 = 50,

    pub const list: []const Actor = @import("zon/actor.zon");
    pub const Key = zhu.enums.fromField(list, "key");

    pub fn get(key: Key) *const Actor {
        return &list[@intFromEnum(key)];
    }
};

pub const dialog = struct {
    pub const Event = union(enum) {
        finish,
        openWeaponShop,
        openPotionShop,
        openSale,
        battle: Actor.Key,
        showSwordTip,
        showEnding,
    };

    pub const Line = struct {
        actor: ?Actor.Key,
        content: []const u8 = &.{},
        event: ?Event = null,
    };

    // 一段完整的对话脚本。
    pub const Script = struct {
        id: u16,
        lines: []const Line,
    };
};

pub const dialogues: []const dialog.Script = @import("zon/talk.zon");
pub const factory: Factory = @import("zon/factory.zon");
pub const input = zhu.key.bind(@import("zon/input.zon"));

pub const Chest = struct { tileIndex: u16, pickupIndex: u16 };

pub const Map = struct {
    grid: tiled.Grid,
    back: []const u16,
    ground: []const u16,
    object: []const u8,
    chests: []const Chest = &.{},
    actors: []const Actor.Key = &.{},
};

pub const Portal = struct {
    key: Key,
    target: Key,
    mapId: u8,
    facing: Facing,
    progress: u8 = 0,

    const source = @import("zon/portal.zon");
    pub const Key = zhu.enums.fromField(source, "key");
    pub const list: []const Portal = @import("zon/portal.zon");

    pub fn get(value: Key) *const Portal {
        return &list[@intFromEnum(value)];
    }
};

pub const maps: []const Map = @import("zon/map.zon");

comptime {
    for (dialogues, 0..) |dialogue, id| {
        if (dialogue.id != id) {
            @compileError("对话 ID 必须连续并按顺序排列");
        }
    }
}

test "通过 key 查找角色配置" {
    try std.testing.expectEqualStrings("小飞刀", Actor.get(.player).name);
    try std.testing.expectEqualStrings(
        "小春春",
        Actor.get(.xiaoChunChun).name,
    );
    try std.testing.expectEqualStrings("公  主", Actor.get(.gongZhu).name);
}
