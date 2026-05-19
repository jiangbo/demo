const zhu = @import("zhu");

const template = @import("../template.zig");
const component = @import("../component.zig");
const context = @import("../context.zig");
const map = @import("../map.zig");

const Crop = component.Crop;
const Player = component.Player;
const Position = component.Position;
const Sprite = component.Sprite;
const Render = component.Render;
const YSort = component.YSort;
const Target = component.Target;

pub fn update(world: *zhu.ecs.World) void {
    if (!zhu.window.mouse.pressed(.LEFT)) return;

    const player = world.getIdentityEntity(Player).?;
    const target = world.get(player, Target).?;
    if (!target.active) return;

    switch (context.tool) {
        .hoe => map.hoe(target.position),
        .water => waterTarget(world, target.position),
        .seed => plant(world, target.position),
    }
}

fn waterTarget(world: *zhu.ecs.World, position: zhu.Vector2) void {
    map.water(position);

    const cell = map.getCell(position) orelse return;
    if (cell.crop) |crop_entity| {
        if (world.getPtr(crop_entity, Crop)) |crop| {
            crop.watered = true;
        }
    }
}

fn plant(world: *zhu.ecs.World, position: zhu.Vector2) void {
    const cell = map.getCell(position) orelse return;
    if (cell.land == null or cell.crop != null) return;

    const sprite_config = template.farm.crop.stages.seed;
    const entity = world.createEntity();
    world.add(entity, Crop{});
    world.add(entity, Position.xy(position.x, position.y));
    world.add(entity, Sprite{
        .image = spriteImage(sprite_config),
        .offset = sprite_config.offset,
    });
    world.add(entity, Render{ .layer = .crop });
    world.add(entity, YSort{});

    cell.crop = entity;
}

fn spriteImage(comptime sprite: anytype) zhu.graphics.Image {
    const rect = sprite.rect;
    if (zhu.getImage(sprite.path)) |source| return source.sub(rect);
    return zhu.batch.whiteImage.sub(rect);
}
