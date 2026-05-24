const zhu = @import("zhu");

const factory = @import("../factory.zig");
const component = @import("../component.zig");
const toolbar = @import("../toolbar.zig");
const land = @import("../map.zig").land;

const Crop = component.farm.Crop;
const Player = component.actor.Player;
const Target = component.ui.Target;

pub fn update(world: *zhu.ecs.World) void {
    if (!zhu.window.mouse.pressed(.LEFT)) return;

    const player = world.getIdentity(Player).?;
    const target = world.get(player, Target).?;
    if (!target.active) return;

    const tile = land.getTile(target.position) orelse return;

    if (tile.crop) |entity| {
        const crop = world.get(entity, Crop) orelse return;
        if (crop.stage != .mature) return;

        world.destroyEntity(entity);
        tile.crop = null;
        const pickupEntity = factory.spawnPickup(world, .crop);
        world.add(pickupEntity, target.position);
        return;
    }

    if (toolbar.active()) |tool| {
        switch (tool.type) {
            .hoe => land.hoe(target.position),
            .water => waterTarget(world, target.position),
            .seed => plant(world, target.position),
            .crop => {},
        }
    }
}

fn waterTarget(world: *zhu.ecs.World, position: zhu.Vector2) void {
    land.water(position);

    const tile = land.getTile(position) orelse return;
    if (tile.crop) |entity| {
        if (world.getPtr(entity, Crop)) |crop| {
            crop.watered = true;
        }
    }
}

fn plant(world: *zhu.ecs.World, position: zhu.Vector2) void {
    const tile = land.getTile(position) orelse return;
    if (tile.land == null or tile.crop != null) return;

    toolbar.active().?.count -= 1;
    const entity = factory.spawnCrop(world, position);
    tile.crop = entity;
}
