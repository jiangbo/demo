const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const components = @import("components.zig");

const Player = components.Player;
const Enemy = components.Enemy;
const WantToMove = components.WantToMove;
const TilePosition = components.TilePosition;
const WantToAttack = components.WantToAttack;

pub fn checkPlayerAttack() void {
    const playerEntity = ecs.w.getIdentityEntity(Player).?;

    const moved = ecs.w.get(playerEntity, WantToMove);
    if (moved == null) return;
    const tilePosition = moved.?[0];

    var view = ecs.w.view(.{ Enemy, TilePosition });
    while (view.next()) |enemy| {
        const position = view.get(enemy, TilePosition);
        if (!tilePosition.equals(position)) continue;

        const enemyEntity = ecs.w.toEntity(enemy).?;
        ecs.w.add(playerEntity, WantToAttack{enemyEntity});
        ecs.w.remove(playerEntity, WantToMove);
        return;
    }
}
