const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;
const ecs = zhu.ecs;

const map = @import("map.zig");
const battle = @import("battle.zig");
const component = @import("component.zig");

const Player = component.Player;
const Enemy = component.Enemy;
const WantToAttack = component.WantToAttack;
const Health = component.Health;
const TurnState = component.TurnState;
const Position = component.Position;
const TilePosition = component.TilePosition;
const TileRect = component.TileRect;
const Amulet = component.Amulet;
const ViewField = component.ViewField;
const PlayerView = component.PlayerView;

var entity: ecs.Entity = undefined;
const viewSize = 4;

pub fn init() void {
    entity = ecs.w.createIdentityEntity(Player);

    const tilePos = map.rooms[0].center();
    ecs.w.add(entity, tilePos);
    ecs.w.add(entity, map.getTextureFromTile(.player));
    ecs.w.add(entity, map.worldPosition(tilePos));
    const health: Health = .{ .max = 10, .current = 10 };
    ecs.w.add(entity, health);
    ecs.w.add(entity, ViewField{.fromCenter(tilePos, viewSize)});
    ecs.w.add(entity, PlayerView{});
    map.updatePlayerWalk();

    cameraFollow(map.worldPosition(tilePos));
}

pub fn update() void {
    if (!window.isAnyRelease()) return; // 没有按任何键

    if (window.isKeyRelease(.SPACE)) {
        // 空格跳过当前回合
        ecs.w.addContext(TurnState.monster);
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
    } else moveOrAttack(newPos);

    battle.attack();
}

fn moveOrAttack(newPos: TilePosition) void {
    ecs.w.addContext(TurnState.monster);
    if (!map.canMove(newPos)) return; // 不能移动，撞墙也算移动

    var view = ecs.w.view(.{ Enemy, TilePosition });
    while (view.next()) |enemy| {
        const position = view.get(enemy, TilePosition);
        if (!newPos.equals(position)) continue;

        const enemyEntity = ecs.w.toEntity(enemy).?;
        ecs.w.add(entity, WantToAttack{enemyEntity});
        return;
    }

    ecs.w.add(entity, newPos);
    ecs.w.add(entity, ViewField{.fromCenter(newPos, viewSize)});
    ecs.w.add(entity, map.worldPosition(newPos));
    map.updatePlayerWalk();
    map.updateDistance(newPos);
    cameraFollow(map.worldPosition(newPos));
}

fn cameraFollow(position: Position) void {
    const scaleSize = window.logicSize.div(camera.scale);
    const half = scaleSize.scale(0.5);
    const max = map.size.sub(scaleSize).max(.zero);
    camera.position = position.sub(half).clamp(.zero, max);
}
