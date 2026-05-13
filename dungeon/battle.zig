const std = @import("std");
const zhu = @import("zhu");

const ecs = zhu.ecs;

const component = @import("component.zig");

const Player = component.Player;
const Enemy = component.Enemy;
const WantToMove = component.WantToMove;
const TilePosition = component.TilePosition;
const WantToAttack = component.WantToAttack;
const Health = component.Health;
const TurnState = component.TurnState;

pub fn attack() void {
    var view = ecs.w.view(.{ WantToAttack, component.Damage });
    while (view.next()) |entity| {
        const target = ecs.w.get(entity, WantToAttack)[0];
        const targetIndex = ecs.w.toIndex(target) orelse continue;

        var health = ecs.w.tryGetPtr(targetIndex, Health) orelse continue;
        const damage = ecs.w.get(entity, component.Damage).v;
        health.current -= damage;
        if (health.current <= 0) {
            if (ecs.w.isIdentity(target, Player)) {
                ecs.w.addContext(TurnState.over);
            } else ecs.w.destroyEntity(target);
        }
    }
    ecs.w.clear(WantToAttack);
}
