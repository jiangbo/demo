const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const camera = zhu.camera;

const scene = @import("scene.zig");
const component = @import("component.zig");
const map = @import("map.zig");
const zon = @import("zon.zig");
const system = @import("system/system.zig");
const ui = @import("ui/ui.zig");

const actorComponent = component.actor;
const dialog = component.dialog;
const Actor = actorComponent.Actor;
const Dialog = dialog.Dialog;
const Enemy = actorComponent.Enemy;
const Interact = component.Interact;
const Player = actorComponent.Player;
const Talk = dialog.Talk;

pub var back: union(enum) {
    none,
    battle,
    load: u8,
    menu: u8,
} = .none;

pub fn enter(world: *ecs.World, allocator: zhu.Allocator) void {
    ui.reset();
    switch (back) {
        .none => {
            map.reset(world);
            map.enter(world, allocator, .{
                .location = .{
                    .portal = .start,
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
        },
        .load => |index| {
            const location = map.load(world, index) catch
                @panic("load failed");
            map.enter(world, allocator, .{ .location = location });
        },
        .menu => |index| {
            const location = map.load(world, index) catch
                @panic("load failed");
            map.enter(world, allocator, .{ .location = location });
            ui.openPause();
        },
    }
    camera.directFollow(map.playerPosition(world));
    camera.roundPosition(null);
    zhu.audio.playMusic("voc/back.ogg");
}

// 根据稳定人物标识查找当前地图中的人物实体。
fn findActor(world: *ecs.World, key: zon.Actor.Key) ecs.Entity {
    var query = world.query(.{Actor});
    while (query.next()) |entity| {
        const actor = query.get(entity, Actor);
        if (actor.key == key) return entity;
    }
    unreachable;
}

pub fn update(world: *ecs.World, delta: f32) void {
    if (ui.update(world, delta)) |req| {
        switch (req) {
            .block => {},
            .dialog => |event| handleDialog(world, event),
            .load => |index| {
                back = .{ .menu = index };
                scene.changeScene(.world);
            },
            .save => |index| map.save(world, index) catch
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

const MapState = struct {
    fn update(world: *ecs.World, delta: f32) void {
        system.update(world, delta);
        camera.directFollow(map.playerPosition(world));
        camera.roundPosition(null);

        const portals = world.getEvent(component.event.Portal);
        if (portals.len > 0) {
            map.portalKey = portals[0].key;
            world.clearEvent(component.event.Portal);
            scene.changeMap();
            return;
        }

        if (world.getIdentity(Enemy)) |target| {
            // 是否需要对话
            if (world.get(target, Talk)) |lines| {
                world.removeIdentity(Enemy);
                world.add(world.entity, Dialog{
                    .lines = lines,
                });
                world.add(world.getIdentity(Player).?, Interact.Disabled{});
            } else {
                scene.changeScene(.battle);
            }
            return;
        }

        system.dialog.update(world);
    }
};

fn handleDialog(world: *ecs.World, event: zon.dialog.Event) void {
    switch (event) {
        .finish => {},
        .openWeaponShop => ui.openWeaponShop(),
        .openPotionShop => ui.openPotionShop(),
        .openSale => ui.openSale(),
        .battle => |actorKey| {
            world.addIdentity(findActor(world, actorKey), Enemy);
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
