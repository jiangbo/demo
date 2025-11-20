const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;
const gfx = zhu.gfx;

const map = @import("map.zig");
const battle = @import("battle.zig");
const component = @import("component.zig");

const Player = component.Player;
const Enemy = component.Enemy;
const Health = component.Health;
const Name = component.Name;
const TileRect = component.TileRect;
const TurnState = component.TurnState;
const TilePosition = component.TilePosition;
const WantToMove = component.WantToMove;
const WantToAttack = component.WantToAttack;
const ChasePlayer = component.ChasePlayer;
const PlayerView = component.PlayerView;
const ViewField = component.ViewField;
const Tile = component.Tile;

const MovingRandomly = struct {};
const viewSize = 3;

pub fn init() void {
    const playerView = ecs.w.getIdentity(Player, ViewField).?[0];
    for (map.rooms[1..]) |room| {
        const enemy = ecs.w.createEntity();

        const center = room.center();
        if (playerView.contains(center)) ecs.w.add(enemy, PlayerView{});
        ecs.w.add(enemy, center);
        ecs.w.add(enemy, map.worldPosition(center));

        const enemyTile = switch (zhu.randomIntMost(u8, 1, 10)) {
            0...8 => Tile.goblin,
            else => Tile.orc,
        };

        const hp: i32 = switch (enemyTile) {
            Tile.goblin => 1,
            Tile.orc => 2,
            else => unreachable,
        };
        ecs.w.add(enemy, Health{ .current = hp, .max = hp });
        ecs.w.add(enemy, Name{@tagName(enemyTile)});

        ecs.w.add(enemy, map.getTextureFromTile(enemyTile));
        ecs.w.add(enemy, ChasePlayer{});
        ecs.w.add(enemy, Enemy{});
    }
}

pub fn update() void {
    ecs.w.addContext(TurnState.player);

    moveOrAttack();
    battle.attack();
    map.moveIfNeed();
}

fn moveOrAttack() void {
    const playerEntity = ecs.w.getIdentityEntity(Player).?;
    const playerPos = ecs.w.get(playerEntity, TilePosition).?;
    const rect = ecs.w.get(playerEntity, ViewField).?[0];

    var view = ecs.w.view(.{ ChasePlayer, TilePosition });
    while (view.next()) |entity| {
        var pos = view.get(entity, TilePosition);
        if (rect.contains(pos)) view.add(entity, PlayerView{});
        const enemyRect: TileRect = .fromCenter(pos, viewSize);
        if (!enemyRect.contains(playerPos)) continue;

        const next = map.queryLessDistance(pos) orelse continue;

        if (playerPos.equals(next)) {
            view.add(entity, WantToAttack{playerEntity});
            continue;
        }

        for (ecs.w.raw(TilePosition)) |tilePos| {
            if (!tilePos.equals(next)) continue;

            const step = zhu.math.randomStep(u8, 1);
            if (pos.x == next.x) pos.x +%= step else pos.y +%= step;
            view.add(entity, WantToMove{pos});
            break;
        } else view.add(entity, WantToMove{next});
    }
}
