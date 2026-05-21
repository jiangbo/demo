const zhu = @import("zhu");

const spawn = @import("../spawn.zig");
const component = @import("../component.zig");
const toolbar = @import("../toolbar.zig");
const map = @import("../map.zig");

const Crop = component.Crop;
const Player = component.Player;
const Target = component.Target;

pub fn update(world: *zhu.ecs.World) void {
    if (!zhu.window.mouse.pressed(.LEFT)) return;

    const player = world.getIdentityEntity(Player).?;
    const target = world.get(player, Target).?;
    if (!target.active) return;

    const cell = map.getCell(target.position) orelse return;

    if (cell.crop) |entity| {
        const crop = world.get(entity, Crop) orelse return;
        if (crop.stage != .mature) return;

        world.destroyEntity(entity);
        cell.crop = null;
        spawn.spawnPickup(world, target.position, .crop);
        return;
    }

    if (toolbar.active()) |tool| {
        switch (tool.type) {
            .hoe => map.hoe(target.position),
            .water => waterTarget(world, target.position),
            .seed => plant(world, target.position),
            .crop => {},
        }
    }
}

fn waterTarget(world: *zhu.ecs.World, position: zhu.Vector2) void {
    map.water(position);

    const cell = map.getCell(position) orelse return;
    if (cell.crop) |entity| {
        if (world.getPtr(entity, Crop)) |crop| {
            crop.watered = true;
        }
    }
}

fn plant(world: *zhu.ecs.World, position: zhu.Vector2) void {
    const cell = map.getCell(position) orelse return;
    if (cell.land == null or cell.crop != null) return;

    toolbar.active().?.count -= 1;
    const entity = spawn.spawnCrop(world, position);
    cell.crop = entity;
}
