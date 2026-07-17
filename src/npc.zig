const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const math = zhu.math;

const SIZE: zhu.Vector2 = .xy(32, 32);
const component = @import("component.zig");
const factory = @import("factory.zig");
const map = @import("map.zig");
const player = @import("player.zig");
const Direction = @import("context.zig").Direction;

const Actor = component.Actor;
const Collider = component.Collider;
const Npc = component.Npc;
const Timer = component.Timer;
const World = ecs.World;
pub const zon: []const Character = @import("zon/npc.zon");
var npcPaths: [15][:0]const u8 = blk: {
    var list: [15][:0]const u8 = undefined;
    for (&list, 1..) |*value, i| {
        value.* = std.fmt.comptimePrint("npc{:02}.png", .{i});
    }
    break :blk list;
};
var npcTextures: [npcPaths.len]zhu.Image = undefined;
pub var dead: std.StaticBitSet(64) = .initEmpty();

pub fn init() void {
    for (&npcTextures, &npcPaths) |*texture, path| {
        texture.* = zhu.assets.getImage(zhu.assets.id(path)).?;
    }
}

pub fn enter(world: *World) void {
    var oldQuery = world.query(.{Npc});
    while (oldQuery.next()) |entity| world.destroyEntity(entity);

    for (map.current.npcs) |id| {
        if (dead.isSet(id)) continue;
        const stop = zon[id].speed == 0;
        if (zon[id].progress < player.progress) continue;

        const entity = world.createEntity();
        world.add(entity, Npc{ .index = id });
        world.add(entity, Actor{
            .facing = if (stop) zon[id].facing else .random(),
            .position = .xy(zon[id].x + 16, zon[id].y + 32),
        });
        world.add(entity, Collider{ .size = .xy(16, 16) });
        world.add(entity, factory.npcAnimation(zon[id].picture));
        world.add(entity, Timer{
            .value = .init(zhu.random.float(3, 5)),
        });
    }
}

pub fn update(world: *World, delta: f32) void {
    var query = world.query(.{ Actor, Collider, Npc, Timer });
    while (query.next()) |entity| {
        const actor = query.getPtr(entity, Actor);
        const collider = query.get(entity, Collider);
        const npc = query.get(entity, Npc);
        const timer = query.getPtr(entity, Timer);
        const speed = zon[npc.index].speed * delta;
        if (timer.value.updateFinished(delta) and speed > 0) {
            actor.facing = .random();
            timer.value = .init(zhu.random.float(3, 5));
        }

        const velocity: math.Vector2 = switch (actor.facing) {
            .down => .xy(0, speed),
            .left => .xy(-speed, 0),
            .up => .xy(0, -speed),
            .right => .xy(speed, 0),
        };

        const area = collider.rect(actor.position);
        const min = map.walkTo(area, velocity);
        const newPosition = min.addXY(
            collider.size.x * 0.5,
            collider.size.y,
        );
        // if (newPosition.approxEqual(pos)) {
        //     // 坐标相等，表示没有移动，撞墙了。
        //     const old = npc.facing;
        //     while (old == npc.facing) npc.facing = .random();
        //     npc.timer.reset();
        //     return;
        // }

        // 检测和角色的碰撞
        if (!collider.rect(newPosition).intersect(player.collider())) {
            actor.position = newPosition;
        }
    }
}

pub fn isCollision(world: *World, area: math.Rect) bool {
    var query = world.query(.{ Actor, Collider, Npc });
    while (query.next()) |entity| {
        const actor = query.get(entity, Actor);
        const collider = query.get(entity, Collider);
        if (area.intersect(collider.rect(actor.position))) return true;
    }
    return false;
}

pub fn death(index: u16) void {
    dead.set(index);
}

pub fn talk(
    world: *World,
    collider: math.Rect,
    facing: Direction,
) ?u8 {
    var query = world.query(.{ Actor, Npc });
    while (query.next()) |entity| {
        const actor = query.getPtr(entity, Actor);
        const npc = query.get(entity, Npc);
        if (zon[npc.index].enemy) continue;

        const imagePosition = actor.position.addXY(-16, -32);
        const npcCollider = math.Rect.init(imagePosition, SIZE);
        if (collider.intersect(npcCollider)) {
            // 将 NPC 的面向调整到角色的反方向
            actor.facing = facing.opposite();
            const index: u8 = if (player.progress > 4) 1 else 0;
            return zon[npc.index].talks[index];
        }
    }
    return null;
}

pub fn battle(
    world: *World,
    collider: math.Rect,
    facing: Direction,
) ?u8 {
    var query = world.query(.{ Actor, Npc });
    while (query.next()) |entity| {
        const actor = query.getPtr(entity, Actor);
        const npc = query.get(entity, Npc);
        if (!zon[npc.index].enemy) continue;
        // 战斗的时候，将敌人的碰撞范围扩大
        const imagePosition = actor.position.addXY(-16, -32);
        const pos = imagePosition.sub(SIZE.scale(0.25));
        const area = math.Rect.init(pos, SIZE.scale(1.5));
        if (collider.intersect(area)) {
            // 将 NPC 的面向调整到角色的反方向
            actor.facing = facing.opposite();
            return npc.index;
        }
    }
    return null;
}

pub fn drawTalk(actor: u8) void {
    zhu.batch.drawImage(photo(actor), .xy(40, 400), .{});

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(zon[actor].name, .xy(25, 445), .{
        .color = .yellow,
    });
}

pub fn photo(npcIndex: u16) zhu.Image {
    const texture = npcTextures[zon[npcIndex].picture];
    return texture.sub(.init(.zero, SIZE));
}

pub fn battleTexture(npcIndex: u16) zhu.Image {
    const texture = npcTextures[zon[npcIndex].picture];
    return texture.sub(.init(.xy(0, SIZE.x), SIZE));
}

pub const Character = struct {
    enemy: bool = false,
    talks: []const u8 = &.{},
    name: []const u8 = &.{},
    x: f32 = 0,
    y: f32 = 0,
    picture: u8 = 0,
    facing: Direction = .down,
    // stats: u8,
    level: u16 = 1,
    // exp: u32,
    health: u16 = 0,
    // maxLift: u16,
    attack: u16 = 0,
    defend: u16 = 0,
    speed: f32 = 0,
    goods: []const u8 = &.{},
    money: u16 = 0,
    progress: u8 = 0xFF,
    escape: u8 = 50, // 逃跑成功率
};
