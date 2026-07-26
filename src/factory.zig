const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("component.zig");
const zon = @import("zon.zig");

const actor = component.actor;
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

fn firstImage(animation: Animation, facing: actor.Facing) zhu.Image {
    var value = animation;
    value.source = value.sources[@intFromEnum(facing)];
    return value.subImageAt(0);
}

// 在当前地图创建玩家实体。
pub fn spawnPlayer(
    world: *ecs.World,
    position: zhu.Vector2,
    facing: actor.Facing,
) void {
    const collider = component.Collider.init(
        .xy(-8, -16),
        .xy(16, 16),
    );
    var animation = playerAnimation();
    animation.play(facing);
    const entity = world.createIdentity(actor.Player);
    world.addAll(entity, .{
        actor.Actor{ .key = .player },
        actor.Player{},
        position.sub(collider.min),
        facing,
        collider,
        component.Speed{ .value = 100 },
        animation,
        component.Sprite{
            .image = animation.subImage(),
            .anchor = .xy(0.5, 1),
        },
    });
}

// 根据人物和剧情进度创建当前对话。
pub fn actorTalk(
    key: zon.Actor.Key,
    progress: u8,
) ?component.dialog.Talk {
    const data = zon.Actor.get(key);
    const dialogues = data.dialogues orelse return null;
    const index: usize = if (progress > 4) 1 else 0;
    return zon.dialogues[dialogues[index]].lines;
}

// 根据人物和剧情进度取得当前移动速度。
pub fn actorSpeed(key: zon.Actor.Key, progress: u8) f32 {
    const data = zon.Actor.get(key);
    if (progress > 4) return data.panicSpeed orelse data.speed;
    return data.speed;
}

// 根据配置创建一个 NPC 实体。
pub fn spawnActor(
    world: *ecs.World,
    key: zon.Actor.Key,
    progress: u8,
) void {
    const data = zon.Actor.get(key);
    const entity = world.createEntity();
    var animation = npcAnimation(data.picture);
    animation.play(data.facing);
    world.addAll(entity, .{
        actor.Actor{ .key = key },
        component.Position.xy(data.x + 16, data.y + 32),
        data.facing,
        component.Collider.init(.xy(-8, -16), .xy(16, 16)),
        animation,
        component.Sprite{
            .image = animation.subImage(),
            .anchor = .xy(0.5, 1),
        },
    });

    if (actorTalk(key, progress)) |talk| {
        world.add(entity, talk);
        if (!data.enemy) {
            world.add(entity, component.Interact{});
        }
    }

    if (data.enemy) {
        world.add(entity, actor.Enemy{
            .value = .init(.xy(-24, -40), .xy(48, 48)),
        });
    }

    const speed = actorSpeed(key, progress);
    if (speed == 0) return;
    world.addAll(entity, .{
        component.Speed{ .value = speed },
        actor.Wander{ .value = .init(0) },
    });
}
