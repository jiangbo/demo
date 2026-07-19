const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("component.zig");

const Animation = zhu.Animation;

const NpcAnimation = struct {
    images: [15]zhu.graphics.ImageId,
    size: zhu.Vector2,
    frames: [4]Animation.Frames,
};

const Config = struct {
    player: []const Animation.Source,
    bomb: []const Animation.Source,
    npc: NpcAnimation,
};

// 实体和运行对象的创建配置。
const zon: Config = @import("zon/factory.zon");

pub const ActorConfig = struct {
    key: [:0]const u8,
    enemy: bool = false,
    dialogues: []const u16 = &.{},
    name: []const u8 = &.{},
    x: f32 = 0,
    y: f32 = 0,
    picture: u8 = 0,
    facing: component.Facing = .down,
    level: u16 = 1,
    health: u16 = 0,
    attack: u16 = 0,
    defend: u16 = 0,
    speed: f32 = 0,
    goods: []const u8 = &.{},
    money: u16 = 0,
    progress: u8 = 0xFF,
    escape: u8 = 50,
};

pub const actors: []const ActorConfig = @import("zon/actor.zon");

// 根据 ZON 中的 key 生成稳定、可读的角色引用。
pub const Key = blk: {
    var names: [actors.len][]const u8 = undefined;
    var values: [actors.len]u16 = undefined;
    for (actors, 0..) |actor, actorIndex| {
        names[actorIndex] = actor.key;
        values[actorIndex] = actorIndex;
    }

    break :blk @Enum(u16, .exhaustive, &names, &values);
};

pub fn get(key: Key) *const ActorConfig {
    return &actors[@intFromEnum(key)];
}

// 所有 NPC 共用相同的素材布局。
const npcSources: [15][4]Animation.Source = blk: {
    var sources: [15][4]Animation.Source = undefined;
    for (zon.npc.images, 0..) |imageId, imageIndex| {
        for (zon.npc.frames, 0..) |frames, sourceIndex| {
            sources[imageIndex][sourceIndex] = .{
                .imageId = imageId,
                .size = zon.npc.size,
                .frames = frames,
            };
        }
    }
    break :blk sources;
};

// 创建角色动画。
pub fn playerAnimation() Animation {
    return .initSource(zon.player);
}

// 创建爆炸动画。
pub fn bombAnimation() Animation {
    return .initSource(zon.bomb);
}

// 创建指定素材的 NPC 动画。
pub fn npcAnimation(picture: u8) Animation {
    return .initSource(&npcSources[picture]);
}

// 获取玩家对话和状态界面使用的头像。
pub fn playerPhoto() zhu.Image {
    return firstImage(playerAnimation(), .down);
}

// 获取玩家在战斗场景使用的图片。
pub fn playerBattleImage() zhu.Image {
    return firstImage(playerAnimation(), .right);
}

// 获取非玩家人物在对话和状态界面使用的头像。
pub fn npcPhoto(key: Key) zhu.Image {
    return firstImage(npcAnimation(get(key).picture), .down);
}

// 获取非玩家人物在战斗场景使用的图片。
pub fn npcBattleImage(key: Key) zhu.Image {
    return firstImage(npcAnimation(get(key).picture), .left);
}

fn firstImage(animation: Animation, facing: component.Facing) zhu.Image {
    var value = animation;
    value.source = value.sources[@intFromEnum(facing)];
    return value.subImageAt(0);
}

// 在当前地图创建玩家实体。
pub fn spawnPlayer(world: *ecs.World, position: zhu.Vector2) void {
    const collider = component.Collider.init(
        .xy(-8, -16),
        .xy(16, 16),
    );
    const entity = world.createIdentity(component.Player);
    world.addAll(entity, .{
        component.Actor{ .key = .player },
        component.Player{},
        position.sub(collider.min),
        component.Facing.down,
        collider,
        component.RenderOffset{ .value = .xy(-2, 4) },
        component.Speed{ .value = 100 },
        playerAnimation(),
    });
}

// 根据配置创建一个 NPC 实体。
pub fn spawnActor(world: *ecs.World, key: Key) void {
    const data = get(key);
    const entity = world.createEntity();
    world.addAll(entity, .{
        component.Actor{ .key = key },
        component.Position.xy(data.x + 16, data.y + 32),
        data.facing,
        component.Collider.init(.xy(-8, -16), .xy(16, 16)),
        npcAnimation(data.picture),
    });

    if (!data.enemy and data.dialogues.len != 0) {
        world.add(entity, component.Talk{});
    }

    if (data.enemy) {
        world.add(entity, component.Enemy{
            .value = .init(.xy(-24, -40), .xy(48, 48)),
        });
    }

    if (data.speed == 0) return;
    world.addAll(entity, .{
        component.Speed{ .value = data.speed },
        component.Wander{ .value = .init(0) },
    });
}

test "通过 key 查找角色配置" {
    try std.testing.expectEqualStrings("小飞刀", get(.player).name);
    try std.testing.expectEqualStrings(
        "小春春",
        get(.xiaoChunChun).name,
    );
    try std.testing.expectEqualStrings("公  主", get(.gongZhu).name);
}
