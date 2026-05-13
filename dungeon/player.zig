const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;
const ecs = zhu.ecs;

const map = @import("map.zig");
const battle = @import("battle.zig");
const item = @import("item.zig");
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
const Item = component.Item;
const Carried = component.Carried;
const Healing = component.Healing;
const Damage = component.Damage;

pub var entity: ecs.Entity = undefined;
const viewSize = 4;

pub fn init() void {
    entity = ecs.w.createIdentityEntity(Player);
    const playerIndex = ecs.w.toIndex(entity).?;

    const tilePos = map.spawns[0];
    ecs.w.add(playerIndex, tilePos);
    ecs.w.add(playerIndex, map.getTextureFromTile(.player));
    ecs.w.add(playerIndex, map.worldPosition(tilePos));
    const health: Health = .{ .max = 10, .current = 10 };
    ecs.w.add(playerIndex, health);
    ecs.w.add(playerIndex, ViewField{.fromCenter(tilePos, viewSize)});
    ecs.w.add(playerIndex, PlayerView{});
    ecs.w.add(playerIndex, Damage{ .v = 1 });
    map.updatePlayerWalk();

    cameraFollow(map.worldPosition(tilePos));
}

pub fn update() void {
    if (!window.isAnyRelease()) return; // 没有按任何键

    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q })) {
        map.minMap = false;
    }

    const playerIndex = ecs.w.toIndex(entity).?;
    const playerPos = ecs.w.get(playerIndex, TilePosition);
    if (window.isKeyRelease(.G)) { // 拾取物品
        // 找到在角色视野中的物品，判断是否可以拾取
        var view = ecs.w.view(.{ Item, TilePosition, PlayerView });
        while (view.next()) |itemEntity| {
            const pos = ecs.w.get(itemEntity, TilePosition);
            if (!playerPos.equals(pos)) continue;
            // 找到一个物品可以拾取
            ecs.w.addContext(TurnState.monster);
            ecs.w.remove(itemEntity, TilePosition);
            ecs.w.remove(itemEntity, Position);
            ecs.w.remove(itemEntity, gfx.Texture);
            ecs.w.add(itemEntity, Carried{});
            return;
        }
    }

    const start: u32 = @intFromEnum(zhu.input.KeyCode._0);
    var view = ecs.w.view(.{ Item, Carried });
    var index: u8 = 1;
    while (view.next()) |itemEntity| : (index += 1) {
        if (index > 9) break;
        if (!window.isKeyRelease(@enumFromInt(start + index))) continue;

        if (ecs.w.tryGet(itemEntity, Healing)) |heal| { // 使用药水
            const h = ecs.w.getPtr(playerIndex, Health);
            h.current = @min(h.max, h.current + heal.v);
        } else if (ecs.w.tryGet(itemEntity, Damage)) |damage| {
            ecs.w.add(playerIndex, damage);
        } else map.minMap = !map.minMap;

        ecs.w.assure(Carried).orderedRemove(itemEntity);
        ecs.w.destroy(itemEntity);
        ecs.w.addContext(TurnState.monster);
        return;
    }

    var newPos = playerPos;
    if (window.isKeyRelease(.W)) newPos.y -|= 1 //
    else if (window.isKeyRelease(.S)) newPos.y += 1 //
    else if (window.isKeyRelease(.A)) newPos.x -|= 1 //
    else if (window.isKeyRelease(.D)) newPos.x += 1; //

    if (playerPos.equals(newPos)) return; // 没有移动

    if (map.finalPos.equals(newPos)) {
        const final = map.currentLevel == map.MAX_LEVEL;
        const state: TurnState = if (final) .win else .next;
        ecs.w.addContext(state);
    } else moveOrAttack(newPos);

    battle.attack();
}

fn moveOrAttack(newPos: TilePosition) void {
    ecs.w.addContext(TurnState.monster);
    if (!map.canMove(newPos)) return; // 不能移动，撞墙也算移动

    var view = ecs.w.view(.{ Enemy, TilePosition });
    while (view.next()) |enemy| {
        const position = ecs.w.get(enemy, TilePosition);
        if (!newPos.equals(position)) continue;

        const enemyEntity = view.toEntity(enemy);
        const playerIndex = ecs.w.toIndex(entity).?;
        ecs.w.add(playerIndex, WantToAttack{enemyEntity});
        return;
    }

    const viewField = ViewField{.fromCenter(newPos, viewSize)};
    const playerIndex = ecs.w.toIndex(entity).?;
    ecs.w.add(playerIndex, newPos);
    ecs.w.add(playerIndex, viewField);
    ecs.w.add(playerIndex, map.worldPosition(newPos));

    item.update();

    map.updatePlayerWalk();
    map.updateDistance(newPos);
    cameraFollow(map.worldPosition(newPos));
}

fn cameraFollow(position: Position) void {
    // const scaleSize = window.logicSize.div(camera.scale);
    const scaleSize = window.logicSize;
    const half = scaleSize.scale(0.5);
    const max = map.size.sub(scaleSize).max(.zero);
    camera.position = position.sub(half).clamp(.zero, max);
}
