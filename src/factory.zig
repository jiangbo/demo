const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("component.zig");
const storage = @import("storage.zig");
const zon = @import("zon.zig");

const actor = component.actor;
const Animation = zhu.Animation;
const Portal = component.map.Portal;

// 所有 NPC 共用相同的素材布局。
const npcSources: [15][4]Animation.Source = blk: {
    var sources: [15][4]Animation.Source = undefined;
    for (zon.config.npc.images, 0..) |imageId, imageIndex| {
        for (zon.config.npc.frames, 0..) |frames, sourceIndex| {
            sources[imageIndex][sourceIndex] = .{
                .imageId = imageId,
                .size = zon.config.npc.size,
                .frames = frames,
            };
        }
    }
    break :blk sources;
};

// 创建角色动画。
pub fn playerAnimation() Animation {
    return .initSource(zon.config.player);
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

// 根据地图配置和长期状态创建地图对象。
pub fn spawnMapObjects(world: *ecs.World, key: zon.Map.Key) void {
    const mapData = zon.Map.get(key);
    spawnPortals(world, mapData);
    spawnChests(world, mapData);
    spawnActors(world, mapData);
}

// 将地图中的相邻传送瓦片创建为区域实体。
fn spawnPortals(world: *ecs.World, mapData: *const zon.Map) void {
    var areas = std.EnumMap(zon.Portal.Key, zhu.Rect).init(.{});
    for (mapData.object, 0..) |value, index| {
        if (value < 5) continue;
        const key: zon.Portal.Key = @enumFromInt(value - 4);
        const tile = mapData.grid.indexToRect(index);
        if (areas.getPtr(key)) |area| {
            const min = area.min.min(tile.min);
            const max = area.max().max(tile.max());
            area.* = .fromMax(min, max);
        } else areas.put(key, tile);
    }

    var iterator = areas.iterator();
    while (iterator.next()) |portal| {
        world.add(world.createEntity(), Portal{
            .key = portal.key,
            .area = portal.value.*,
        });
    }
}

// 根据当前地图和长期状态创建宝箱实体。
fn spawnChests(world: *ecs.World, mapData: *const zon.Map) void {
    const opened = world.getGlobal(storage.OpenedChests).?;
    const atlas = zhu.getImage("maps1-sheet.png").?;
    const images = component.ChestImages{
        .closed = atlas.sub(.init(.xy(35, 511), .square(32))),
        .opened = atlas.sub(.init(.xy(69, 511), .square(32))),
    };
    for (mapData.chests) |place| {
        const isOpened = opened.isSet(place.id);
        const image = if (isOpened) images.opened else images.closed;
        const entity = world.createEntity();
        world.addAll(entity, .{
            component.Chest{ .id = place.id },
            images,
            mapData.grid.indexToWorld(place.tileIndex),
            component.Collider.init(
                .zero,
                mapData.grid.cellSize(),
            ),
            component.Sprite{ .image = image },
        });
        if (!isOpened) world.add(entity, component.Interact{});
    }
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

// 根据地图配置和长期状态创建人物实体。
fn spawnActors(world: *ecs.World, mapData: *const zon.Map) void {
    const deadActors = world.getGlobal(storage.DeadActors).?;
    const progress = world.getGlobal(storage.Progress).?.value;
    for (mapData.actors) |key| {
        if (deadActors.contains(key)) continue;
        if (zon.Actor.get(key).progress < progress) continue;
        spawnActor(world, key, progress);
    }
}

// 根据配置创建一个 NPC 实体。
fn spawnActor(
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

test "相邻瓦片创建一个传送区域实体" {
    const objects = [_]u8{
        1, 5, 5,
        1, 1, 1,
    };
    const mapData = zon.Map{
        .key = "test",
        .grid = .{ .width = 3, .height = 2, .cell = 32 },
        .back = &.{},
        .ground = &.{},
        .object = &objects,
    };

    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();
    spawnPortals(&world, &mapData);

    var query = world.query(.{Portal});
    const entity = query.next().?;
    const portal = query.get(entity, Portal);
    try std.testing.expectEqual(zon.Portal.Key.cityToHome, portal.key);
    try std.testing.expectEqual(zhu.Vector2.xy(32, 0), portal.area.min);
    try std.testing.expectEqual(zhu.Vector2.xy(64, 32), portal.area.size);
    try std.testing.expectEqual(null, query.next());
}
