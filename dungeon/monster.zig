const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const map = @import("map.zig");

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
