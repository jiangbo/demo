const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("component.zig");
const zon = @import("zon.zig");

const Animation = zhu.Animation;

// 所有 NPC 共用相同的素材布局。
const npcSources: [15][4]Animation.Source = blk: {
    var sources: [15][4]Animation.Source = undefined;
    for (zon.factory.npc.images, 0..) |imageId, imageIndex| {
        for (zon.factory.npc.frames, 0..) |frames, sourceIndex| {
            sources[imageIndex][sourceIndex] = .{
                .imageId = imageId,
                .size = zon.factory.npc.size,
                .frames = frames,
            };
        }
    }
    break :blk sources;
};

// 创建角色动画。
pub fn playerAnimation() Animation {
    return .initSource(zon.factory.player);
}

// 创建爆炸动画。
pub fn bombAnimation() Animation {
    return .initSource(zon.factory.bomb);
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
pub fn npcPhoto(key: zon.Actor.Key) zhu.Image {
    return firstImage(npcAnimation(zon.Actor.get(key).picture), .down);
}

// 获取非玩家人物在战斗场景使用的图片。
pub fn npcBattleImage(key: zon.Actor.Key) zhu.Image {
    return firstImage(npcAnimation(zon.Actor.get(key).picture), .left);
}

fn firstImage(animation: Animation, facing: component.Facing) zhu.Image {
    var value = animation;
    value.source = value.sources[@intFromEnum(facing)];
    return value.subImageAt(0);
}

// 在当前地图创建玩家实体。
pub fn spawnPlayer(
    world: *ecs.World,
    position: zhu.Vector2,
    facing: component.Facing,
) void {
    const collider = component.Collider.init(
        .xy(-8, -16),
        .xy(16, 16),
    );
    var animation = playerAnimation();
    animation.play(facing);
    const entity = world.createIdentity(component.Player);
    world.addAll(entity, .{
        component.Actor{ .key = .player },
        component.Player{},
        position.sub(collider.min),
        facing,
        collider,
        component.RenderOffset{ .value = .xy(-2, 4) },
        component.Speed{ .value = 100 },
        animation,
    });
}

// 根据配置创建一个 NPC 实体。
pub fn spawnActor(world: *ecs.World, key: zon.Actor.Key) void {
    const data = zon.Actor.get(key);
    const entity = world.createEntity();
    world.addAll(entity, .{
        component.Actor{ .key = key },
        component.Position.xy(data.x + 16, data.y + 32),
        data.facing,
        component.Collider.init(.xy(-8, -16), .xy(16, 16)),
        npcAnimation(data.picture),
    });

    if (!data.enemy and data.dialogues.len != 0) {
        world.addAll(entity, .{
            component.Interact{},
            component.dialog.Talk{ .dialogues = data.dialogues },
        });
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
