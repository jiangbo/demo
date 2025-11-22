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
    const amulet = ecs.w.createIdentityEntity(Amulet);

    const pos = map.amuletPos;
    ecs.w.add(amulet, pos);
    const texture = map.getTextureFromTile(.amulet);
    ecs.w.alignAdd(amulet, .{ map.worldPosition(pos), texture });
    ecs.w.add(amulet, Item{});
}

pub fn update() void {
    const playerEntity = ecs.w.getIdentityEntity(Player).?;
    const playerPos = ecs.w.get(playerEntity, TilePosition);
    const viewField = ecs.w.get(playerEntity, ViewField)[0];

    var view = ecs.w.viewOption(.{Item}, .{PlayerView}, .{});
    while (view.next()) |item| {
        const itemPos = view.get(item, TilePosition);
        if (viewField.contains(itemPos)) {
            view.add(item, PlayerView{});
        }
    }
    _ = playerPos;
}
