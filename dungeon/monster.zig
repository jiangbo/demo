const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;
const gfx = zhu.gfx;

const map = @import("map.zig");
const components = @import("components.zig");

const Player = components.Player;
const Enemy = components.Enemy;
const Health = components.Health;
const Name = components.Name;
const TurnState = components.TurnState;
const TilePosition = components.TilePosition;
const WantToMove = components.WantToMove;

const MovingRandomly = struct {};

pub fn init() void {
    for (map.rooms[1..]) |room| {
        const enemy = ecs.w.createEntity();

        const center = room.center();
        ecs.w.add(enemy, center);
        ecs.w.add(enemy, map.worldPosition(center));

        const enemyTile = switch (zhu.randomIntMost(u8, 1, 10)) {
            0...8 => map.Tile.goblin,
            else => map.Tile.orc,
        };

        const hp: i32 = switch (enemyTile) {
            map.Tile.goblin => 1,
            map.Tile.orc => 2,
            else => unreachable,
        };
        ecs.w.add(enemy, Health{ .current = hp, .max = hp });
        ecs.w.add(enemy, Name{@tagName(enemyTile)});

        ecs.w.add(enemy, map.getTextureFromTile(enemyTile));
        // ecs.w.add(enemy, MovingRandomly{});
        ecs.w.add(enemy, Enemy{});
    }
}

pub fn move() void {
    if (ecs.w.getContext(TurnState).?.* != .player) return;

    ecs.w.addContext(TurnState.monster);
    var view = ecs.w.view(.{ MovingRandomly, TilePosition });
    while (view.next()) |entity| {
        var pos = view.get(entity, TilePosition);
        switch (zhu.randomIntMost(u8, 0, 3)) {
            0 => pos.x += 1,
            1 => pos.y += 1,
            2 => pos.x -= 1,
            else => pos.y -= 1,
        }
        view.add(entity, WantToMove{pos});
    }
}
