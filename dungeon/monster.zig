const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;
const gfx = zhu.gfx;

const map = @import("map.zig");
const battle = @import("battle.zig");

const MovingRandomly = struct {};

pub fn init() void {
    for (map.rooms[1..]) |room| {
        const enemy = ecs.w.createEntity();

        const center = map.center(room);
        ecs.w.add(enemy, center);
        ecs.w.add(enemy, map.worldPosition(center));

        const enemyTile = switch (zhu.randomInt(u8, 0, 4)) {
            0 => map.Tile.ettin,
            1 => map.Tile.ogre,
            2 => map.Tile.orc,
            else => map.Tile.goblin,
        };

        ecs.w.add(enemy, map.getTextureFromTile(enemyTile));
        ecs.w.add(enemy, MovingRandomly{});
    }
}

pub fn move() void {
    if (ecs.w.getContext(battle.TurnState).?.* != .player) return;

    ecs.w.addContext(battle.TurnState.monster);
    var view = ecs.w.view(.{ MovingRandomly, map.Vec });
    while (view.next()) |entity| {
        const ptr = view.getPtr(entity, map.Vec);
        var pos = ptr.*;
        switch (zhu.randomIntMost(u8, 0, 3)) {
            0 => pos.x += 1,
            1 => pos.y += 1,
            2 => pos.x -= 1,
            else => pos.y -= 1,
        }

        if (map.canEnter(pos)) {
            ptr.* = pos;
            ecs.w.add(entity, map.worldPosition(pos));
        }
    }
}

pub fn checkCollision(playerPosition: map.Vec) void {
    for (ecs.w.raw(map.Vec), ecs.w.data(map.Vec)) |enemyPos, index| {
        if (playerPosition.x == enemyPos.x and
            playerPosition.y == enemyPos.y)
        {
            const entity = ecs.w.getEntity(index).?;
            ecs.w.destroyEntity(entity);
            break;
        }
    }
}
