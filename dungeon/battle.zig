const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const components = @import("components.zig");

const Player = components.Player;
const Enemy = components.Enemy;
const WantToMove = components.WantToMove;
const TilePosition = components.TilePosition;
const WantToAttack = components.WantToAttack;
const Health = components.Health;

pub fn checkPlayerAttack() void {
    const entity = ecs.w.getIdentityEntity(Player).?;

    const moved = ecs.w.get(entity, WantToMove) orelse return;
    const tilePosition = moved[0];

    var view = ecs.w.view(.{ Enemy, TilePosition });
    while (view.next()) |enemy| {
        const position = view.get(enemy, TilePosition);
        if (!tilePosition.equals(position)) continue;

        const enemyEntity = ecs.w.toEntity(enemy).?;
        ecs.w.add(entity, WantToAttack{enemyEntity});
        ecs.w.remove(entity, WantToMove);
        return;
    }
}

pub fn attack() void {
    var view = ecs.w.view(.{WantToAttack});
    while (view.next()) |entity| {
        const target = view.get(entity, WantToAttack)[0];

        var health = ecs.w.getPtr(target, Health) orelse continue;
        health.current -|= 1;
        if (health.current == 0) ecs.w.destroyEntity(target);
    }
    ecs.w.clear(WantToAttack);
}
