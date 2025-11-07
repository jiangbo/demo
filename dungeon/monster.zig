const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;
const gfx = zhu.gfx;

const map = @import("map.zig");
const component = @import("component.zig");

const Player = component.Player;
const Enemy = component.Enemy;
const Health = component.Health;
const Name = component.Name;
const TurnState = component.TurnState;
const TilePosition = component.TilePosition;
const WantToMove = component.WantToMove;
const WantToAttack = component.WantToAttack;
const ChasePlayer = component.ChasePlayer;

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
        ecs.w.add(enemy, ChasePlayer{});
        ecs.w.add(enemy, Enemy{});
    }
}

pub fn move() void {
    if (ecs.w.getContext(TurnState).?.* != .player) return;

    const playerEntity = ecs.w.getIdentityEntity(Player).?;
    const playerPos = ecs.w.get(playerEntity, TilePosition).?;

    ecs.w.addContext(TurnState.monster);
    var view = ecs.w.view(.{ ChasePlayer, TilePosition });
    while (view.next()) |entity| {
        const pos = view.get(entity, TilePosition);
        const next = map.queryLessDistance(pos) orelse continue;

        if (playerPos.equals(next)) {
            view.add(entity, WantToAttack{playerEntity});
        } else {
            view.add(entity, WantToMove{next});
        }
    }
}
