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

    const cell = land.getCell(target.position) orelse return;

    if (cell.crop) |entity| {
        const crop = world.get(entity, Crop) orelse return;
        if (crop.stage != .mature) return;

        world.destroyEntity(entity);
        cell.crop = null;
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

    const cell = land.getCell(position) orelse return;
    if (cell.crop) |entity| {
        if (world.getPtr(entity, Crop)) |crop| {
            crop.watered = true;
        }
    }
}

fn plant(world: *zhu.ecs.World, position: zhu.Vector2) void {
    const cell = land.getCell(position) orelse return;
    if (cell.land == null or cell.crop != null) return;

    toolbar.active().?.count -= 1;
    const entity = factory.spawnCrop(world, position);
    cell.crop = entity;
}
