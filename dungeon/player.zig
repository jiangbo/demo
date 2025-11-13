const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;
const ecs = zhu.ecs;

const map = @import("map.zig");
const component = @import("component.zig");

const Player = component.Player;
const Enemy = component.Enemy;
const WantToAttack = component.WantToAttack;
const Health = component.Health;
const TurnState = component.TurnState;
const TilePosition = component.TilePosition;
const WantToMove = component.WantToMove;
const Amulet = component.Amulet;

pub fn init() void {
    const entity = ecs.w.createIdentityEntity(Player);

    const tilePosition = map.rooms[0].center();
    ecs.w.add(entity, tilePosition);
    ecs.w.add(entity, WantToMove{tilePosition});
    ecs.w.add(entity, map.getTextureFromTile(.player));
    ecs.w.add(entity, map.worldPosition(tilePosition));
    const health: Health = .{ .max = 10, .current = 10 };
    ecs.w.add(entity, health);
    ecs.w.addContext(TurnState.wait);
}

pub fn update() void {
    const entity = ecs.w.getIdentityEntity(Player).?;

    if (window.isKeyRelease(.SPACE)) {
        // 空格跳过当前回合
        ecs.w.addContext(TurnState.player);
        var health = ecs.w.getPtr(entity, Health).?;
        health.current = @min(health.max, health.current + 1);
        return;
    }

    const tilePosition = ecs.w.get(entity, TilePosition).?;
    var newPos = tilePosition;
    if (window.isKeyRelease(.W)) newPos.y -|= 1 //
    else if (window.isKeyRelease(.S)) newPos.y += 1 //
    else if (window.isKeyRelease(.A)) newPos.x -|= 1 //
    else if (window.isKeyRelease(.D)) newPos.x += 1; //

    if (tilePosition.equals(newPos)) return; // 没有移动

    const amuletPos = ecs.w.getIdentity(Amulet, TilePosition).?;
    if (amuletPos.equals(newPos)) {
        ecs.w.addContext(TurnState.win);
    } else moveOrAttack(entity, newPos);
}

fn moveOrAttack(entity: ecs.Entity, newPos: TilePosition) void {
    ecs.w.addContext(TurnState.player);
    ecs.w.add(entity, WantToMove{newPos});

    var view = ecs.w.view(.{ Enemy, TilePosition });
    while (view.next()) |enemy| {
        const position = view.get(enemy, TilePosition);
        if (!newPos.equals(position)) continue;

        const enemyEntity = ecs.w.toEntity(enemy).?;
        ecs.w.add(entity, WantToAttack{enemyEntity});
        ecs.w.remove(entity, WantToMove);
        return;
    }
}
