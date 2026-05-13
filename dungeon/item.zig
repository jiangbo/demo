const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const ecs = zhu.ecs;

const map = @import("map.zig");
const component = @import("component.zig");

const TilePosition = component.TilePosition;
const Amulet = component.Amulet;
const Player = component.Player;
const PlayerView = component.PlayerView;
const ViewField = component.ViewField;
const Item = component.Item;

pub fn init() void {
    if (map.currentLevel == map.MAX_LEVEL) {
        spawnAmulet();
    } else {
        spawnExit();
    }
}

fn spawnAmulet() void {
    const amulet = ecs.w.createIdentityEntity(Amulet);
    const amuletIndex = ecs.w.toIndex(amulet).?;

    const pos = map.finalPos;
    ecs.w.add(amuletIndex, pos);
    const texture = map.getTextureFromTile(.amulet);
    ecs.w.alignAdd(amuletIndex, .{ map.worldPosition(pos), texture });
    ecs.w.add(amuletIndex, Item{});
}

fn spawnExit() void {
    const exit = ecs.w.createEntity();
    const exitIndex = ecs.w.toIndex(exit).?;

    const pos = map.finalPos;
    ecs.w.add(exitIndex, pos);
    const texture = map.getTextureFromTile(.exit);
    ecs.w.alignAdd(exitIndex, .{ map.worldPosition(pos), texture });
    ecs.w.add(exitIndex, Item{});
}

pub fn update() void {
    const playerEntity = ecs.w.getIdentityEntity(Player).?;
    const playerIndex = ecs.w.toIndex(playerEntity).?;
    const viewField = ecs.w.get(playerIndex, ViewField)[0];

    var view = ecs.w.viewOption(.{Item}, .{PlayerView}, .{});
    while (view.next()) |item| {
        const itemPos = ecs.w.get(item, TilePosition);
        if (viewField.contains(itemPos)) {
            ecs.w.add(item, PlayerView{});
        }
    }
}
