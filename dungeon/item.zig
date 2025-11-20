const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const ecs = zhu.ecs;

const map = @import("map.zig");
const component = @import("component.zig");

const TilePosition = component.TilePosition;
const Amulet = component.Amulet;

pub fn init() void {
    const amulet = ecs.w.createIdentityEntity(Amulet);

    const last = map.spawns[map.spawns.len - 1];
    ecs.w.add(amulet, last);
    const texture = map.getTextureFromTile(.amulet);
    ecs.w.alignAdd(amulet, .{ map.worldPosition(last), texture });
}
