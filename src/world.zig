const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const camera = zhu.camera;
const math = zhu.math;

const scene = @import("scene.zig");
const component = @import("component.zig");
const map = @import("map.zig");
const factory = @import("factory.zig");
const zon = @import("zon.zig");
const system = @import("system/system.zig");
const context = @import("context.zig");
const ui = @import("ui/ui.zig");
const storage = @import("storage.zig");

const actorComponent = component.actor;
const dialog = component.dialog;
const Actor = actorComponent.Actor;
const Collider = component.Collider;
const Dialog = dialog.Dialog;
const Enemy = actorComponent.Enemy;
const Facing = actorComponent.Facing;
const Interact = component.Interact;
const Player = actorComponent.Player;
const Position = component.Position;
const Portal = component.Portal;
const Talk = dialog.Talk;

const PlayerLocation = struct {
    position: math.Vector2,
    facing: Facing,
};

const PlayerSpawn = union(enum) {
    location: PlayerLocation,
    portal: zon.Portal.Key,
};

pub var back: enum { none, battle, load, menu } = .none;
pub fn init(_: *ecs.World) void {
    ui.init();
    map.init();
}

pub fn deinit() void {
    zhu.audio.setMusicState(.stopped);
}

pub fn enter(world: *ecs.World) void {
    map.enter();
    ui.reset();
    switch (back) {
        .none => {
            world.addAll(world.entity, .{
                storage.DeadActors.empty,
                storage.OpenedChests.initEmpty(),
                storage.Progress{},
                storage.Stats{},
                storage.Inventory{},
            });
            rebuildMap(world, .{
                .location = .{
                    .position = .xy(180, 164),
                    .facing = .down,
                },
            });
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[2].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
        },
        .battle => {
            system.story.update(world);
            finishBattle(world);
        },
        .load => {
            rebuildMap(world, .{ .location = loadPlayerLocation.? });
        },
        .menu => {
            if (loadPlayerLocation) |location| {
                rebuildMap(world, .{ .location = location });
            }
            ui.openPause();
        },
    }
    loadPlayerLocation = null;
    camera.directFollow(playerPosition(world));
    zhu.audio.playMusic("voc/back.ogg");
}

pub fn changeMap(world: *ecs.World) void {
    map.enter();
    rebuildMap(world, .{ .portal = map.portalKey });
}

// 清空旧地图并创建新地图的实体。
fn rebuildMap(world: *ecs.World, spawn: PlayerSpawn) void {
    world.resetKeep(storage.keep);
    world.entity = world.createEntity();
    map.spawnPortals(world);
    factory.spawnChests(world, map.current);
    switch (spawn) {
        .location => |location| factory.spawnPlayer(
            world,
            location.position,
            location.facing,
        ),
        .portal => |key| spawnPlayerAtPortal(world, key),
    }

    const deadActors = world.getGlobal(storage.DeadActors).?;
    const progress = world.getGlobal(storage.Progress).?.value;
    for (map.current.actors) |key| {
        if (deadActors.contains(key)) continue;
        if (zon.Actor.get(key).progress < progress) continue;
        factory.spawnActor(world, key, progress);
    }
    camera.directFollow(playerPosition(world));
}

// 在目标传送区域外创建玩家。
fn spawnPlayerAtPortal(world: *ecs.World, key: zon.Portal.Key) void {
    const config = zon.Portal.get(key);
    var query = world.query(.{Portal});
    while (query.next()) |entity| {
        const portal = query.get(entity, Portal);
        if (portal.key != key) continue;

        const center = portal.area.center();
        const max = portal.area.max();
        const position = switch (config.facing) {
            .down => math.Vector2.xy(center.x - 8, max.y + 8),
            .left => math.Vector2.xy(
                portal.area.min.x - 16 - 8,
                center.y - 8,
            ),
            .up => math.Vector2.xy(
                center.x - 8,
                portal.area.min.y - 16 - 8,
            ),
            .right => math.Vector2.xy(max.x + 8, center.y - 8),
        };
        factory.spawnPlayer(world, position, config.facing);
        return;
    }
    unreachable;
}

// 处理战斗结果并继续使用进入战斗前的地图实体。
fn finishBattle(world: *ecs.World) void {
    const actorEntity = findBattleActor(world);

    switch (context.battle.result) {
        .fighting => unreachable,
        .win => {
            const dead = world.getGlobal(storage.DeadActors).?;
            dead.insert(context.battle.actor);
            if (world.getIdentity(Interact)) |entity| {
                if (entity == actorEntity) {
                    world.removeIdentity(Interact);
                }
            }
            world.destroyEntity(actorEntity);
        },
        .escape => {
            world.getPtr(actorEntity, Enemy).?.wait = 0.5;
            if (world.has(world.entity, Dialog)) {
                world.remove(world.entity, Dialog);
                world.remove(world.getIdentity(Player).?, Interact.Disabled);
            }
            world.removeIdentity(Interact);
        },
    }
}

// 根据稳定人物标识查找当前地图中的战斗实体。
fn findBattleActor(world: *ecs.World) ecs.Entity {
    var query = world.query(.{Actor});
    while (query.next()) |entity| {
        const actor = query.get(entity, Actor);
        if (actor.key == context.battle.actor) return entity;
    }
    unreachable;
}

test "战斗胜利后保留对话并删除人物实体" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    world.add(world.entity, storage.DeadActors.empty);
    const playerEntity = world.createIdentity(Player);
    world.add(world.entity, Dialog{
        .lines = zon.dialogues[36].lines,
    });
    world.add(playerEntity, Interact.Disabled{});
    const actorEntity = world.createEntity();
    world.add(actorEntity, Actor{ .key = .wuPi });

    context.battle = .{
        .actor = .wuPi,
        .portalKey = .start,
        .result = .win,
    };

    finishBattle(&world);

    try std.testing.expect(world.has(world.entity, Dialog));
    try std.testing.expect(world.has(playerEntity, Interact.Disabled));
    try std.testing.expect(!world.has(actorEntity, Actor));
    const deadActors = world.getGlobal(storage.DeadActors).?;
    try std.testing.expect(deadActors.contains(.wuPi));
}

test "战斗胜利后没有对话则返回地图" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    world.add(world.entity, storage.DeadActors.empty);
    const actorEntity = world.createEntity();
    world.add(actorEntity, Actor{ .key = .senLin_feiJiangJun1 });

    context.battle = .{
        .actor = .senLin_feiJiangJun1,
        .portalKey = .start,
        .result = .win,
    };

    finishBattle(&world);

    try std.testing.expect(!world.has(world.entity, Dialog));
    try std.testing.expect(!world.has(actorEntity, Actor));
}

test "逃跑后关闭对话并保留冷却中的敌人" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    const playerEntity = world.createIdentity(Player);
    world.add(world.entity, Dialog{
        .lines = zon.dialogues[36].lines,
    });
    world.add(playerEntity, Interact.Disabled{});
    const actorEntity = world.createEntity();
    world.addAll(actorEntity, .{
        Actor{ .key = .wuPi },
        Enemy{ .value = .init(.zero, .xy(48, 48)) },
        Interact{},
    });
    world.addIdentity(actorEntity, Interact);

    context.battle = .{
        .actor = .wuPi,
        .portalKey = .start,
        .result = .escape,
    };

    finishBattle(&world);

    try std.testing.expect(!world.has(world.entity, Dialog));
    try std.testing.expect(!world.has(playerEntity, Interact.Disabled));
    try std.testing.expectEqual(null, world.getIdentity(Interact));
    try std.testing.expectEqual(
        @as(f32, 0.5),
        world.get(actorEntity, Enemy).?.wait,
    );
}

pub fn exit() void {}

pub fn update(world: *ecs.World, delta: f32) void {
    if (ui.update(world, delta)) |req| {
        switch (req) {
            .block => {},
            .dialog => |event| handleDialog(event),
            .load => |index| {
                load(world, index) catch return;
                back = .menu;
                scene.changeScene(.world);
            },
            .save => |index| save(world, index) catch
                @panic("save failed"),
            .title => scene.changeScene(.title),
        }
        return;
    }

    if (zon.input.released(.menu) or zon.input.released(.cancel) or
        zhu.mouse.released(.RIGHT))
    {
        ui.openPause();
        return;
    }

    MapState.update(world, delta);
}

pub fn draw(world: *ecs.World) void {
    map.draw();
    system.render.draw(world);

    camera.push(.window);
    defer camera.pop();
    ui.draw(world);
}

const MapState = struct {
    var warn: bool = false;

    fn update(world: *ecs.World, delta: f32) void {
        system.update(world, delta);
        camera.directFollow(playerPosition(world));

        // 检测是否需要切换地图
        if (world.getIdentity(Portal)) |portalEntity| {
            const portal = world.get(portalEntity, Portal).?;
            if (!warn) return changeMapIfNeed(world, portal.key);
        } else warn = false;

        if (world.getIdentity(Enemy)) |target| {
            world.removeIdentity(Enemy);
            const targetActor = world.get(target, Actor).?;
            // 是否需要对话
            if (world.get(target, Talk)) |lines| {
                world.add(world.entity, Dialog{
                    .lines = lines,
                });
                world.add(world.getIdentity(Player).?, Interact.Disabled{});
            } else {
                context.battle = .{
                    .actor = targetActor.key,
                    .portalKey = map.portalKey,
                };
                back = .battle;
                scene.changeScene(.battle);
            }
            return;
        }

        system.dialog.update(world);
    }

    fn changeMapIfNeed(world: *ecs.World, key: zon.Portal.Key) void {
        const portal = zon.Portal.get(key);
        const progress = world.getGlobal(storage.Progress).?.value;
        if (progress > portal.progress) {
            std.log.info("change map portal: {s}", .{@tagName(key)});
            map.portalKey = portal.target;
            scene.changeMap();
            return;
        }

        if (progress == 1) {
            warn = true;
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[5].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
        }

        if (progress == 4) {
            world.addEvent(component.event.Story{
                .progress = progress,
            });
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[32].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
        }

        if (progress == 10) {
            warn = true;
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[37].lines,
            });
            world.add(world.getIdentity(Player).?, Interact.Disabled{});
        }
    }
};

var loadPlayerLocation: ?PlayerLocation = null;
pub fn load(world: *ecs.World, index: u8) !void {
    var loaded = try storage.read(index);
    defer loaded.deinit();

    const record = loaded.value;
    map.portalKey = record.portal;
    world.addAll(world.entity, .{
        record.progress,
        record.stats,
        record.inventory,
    });
    loadPlayerLocation = .{
        .position = record.position,
        .facing = record.facing,
    };

    const opened = world.getGlobal(storage.OpenedChests).?;
    opened.* = .initEmpty();
    for (record.openedChests) |chestId| {
        opened.set(chestId);
    }

    const deadActors = world.getGlobal(storage.DeadActors).?;
    deadActors.* = .empty;
    for (record.deadActors) |key| {
        deadActors.insert(key);
    }
}

fn save(world: *ecs.World, index: u8) !void {
    var openedChestBuffer: [zon.Chest.list.len]u16 = undefined;
    var openedChestCount: usize = 0;
    const opened = world.getGlobal(storage.OpenedChests).?;
    var chestIterator = opened.iterator(.{});
    while (chestIterator.next()) |chestId| {
        openedChestBuffer[openedChestCount] = @intCast(chestId);
        openedChestCount += 1;
    }

    var deadKeys: [storage.DeadActors.len]zon.Actor.Key = undefined;
    var deadActorCount: usize = 0;
    const deadActors = world.getGlobal(storage.DeadActors).?;
    var actorIterator = deadActors.iterator();
    while (actorIterator.next()) |key| {
        deadKeys[deadActorCount] = key;
        deadActorCount += 1;
    }

    try storage.write(index, .{
        .portal = map.portalKey,
        .position = playerPosition(world),
        .facing = world.get(world.getIdentity(Player).?, Facing).?,
        .progress = world.getGlobal(storage.Progress).?.*,
        .stats = world.getGlobal(storage.Stats).?.*,
        .inventory = world.getGlobal(storage.Inventory).?.*,
        .openedChests = openedChestBuffer[0..openedChestCount],
        .deadActors = deadKeys[0..deadActorCount],
    });
}

// 返回玩家碰撞区域的位置，用于相机跟随和存档。
fn playerPosition(world: *ecs.World) math.Vector2 {
    const entity = world.getIdentity(Player).?;
    const position = world.get(entity, Position).?;
    const collider = world.get(entity, Collider).?;
    return collider.move(position).min;
}

fn handleDialog(event: zon.dialog.Event) void {
    switch (event) {
        .finish => {},
        .openWeaponShop => ui.openWeaponShop(),
        .openPotionShop => ui.openPotionShop(),
        .openSale => ui.openSale(),
        .battle => |actorKey| {
            context.battle = .{
                .actor = actorKey,
                .portalKey = map.portalKey,
            };
            back = .battle;
            scene.changeScene(.battle);
        },
        .showSwordTip => {
            // 打败了巫批，对话完成
            ui.story.open(.sword);
        },
        .showEnding => {
            // 打败了大魔王
            ui.story.open(.ending);
        },
    }
}
