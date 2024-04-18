const std = @import("std");
const component = @import("component.zig");
const asset = @import("asset.zig");
const resource = @import("resource.zig");
const engine = @import("engine.zig");

pub fn spawn(ctx: *engine.Context) void {
    const map = resource.Map.init(asset.dungeon);
    ctx.registry.singletons().getOrAdd(resource.Map).* = map;

    spawnPlayer(ctx, map);
    spawnEnemies(ctx, map);
    spawnAmulet(ctx, map);

    const center = map.rooms[0].center();
    const camera = resource.Camera.init(center.x, center.y);
    ctx.registry.singletons().getOrAdd(resource.Camera).* = camera;
}

fn spawnPlayer(ctx: *engine.Context, map: resource.Map) void {
    const player = ctx.registry.create();
    const center = component.Position{ .vec = map.rooms[0].center() };
    ctx.registry.add(player, center);
    const index = @intFromEnum(resource.TileType.player);
    const sprite = component.Sprite{ .sheet = map.sheet, .index = index };
    ctx.registry.add(player, sprite);
    ctx.registry.add(player, component.Player{});
    ctx.registry.add(player, component.Health{ .current = 20, .max = 20 });
}

fn spawnEnemies(ctx: *engine.Context, map: resource.Map) void {
    for (map.rooms[1..]) |room| {
        const enemy = ctx.registry.create();
        const center = component.Position{ .vec = room.center() };
        ctx.registry.add(enemy, center);

        const enemyType = switch (engine.randomValue(0, 4)) {
            0 => resource.TileType.ettin,
            1 => resource.TileType.ogre,
            2 => resource.TileType.orc,
            else => resource.TileType.goblin,
        };

        const health = switch (enemyType) {
            .ettin => component.Health{ .current = 10, .max = 10 },
            .ogre => component.Health{ .current = 5, .max = 5 },
            .orc => component.Health{ .current = 15, .max = 15 },
            .goblin => component.Health{ .current = 3, .max = 3 },
            else => unreachable,
        };

        ctx.registry.add(enemy, health);
        const index = @intFromEnum(enemyType);
        const sprite = component.Sprite{ .sheet = map.sheet, .index = index };
        ctx.registry.add(enemy, sprite);
        ctx.registry.add(enemy, component.Enemy{});
        ctx.registry.add(enemy, component.Name{ .value = @tagName(enemyType) });
    }
}

fn spawnAmulet(ctx: *engine.Context, map: resource.Map) void {
    const amulet = ctx.registry.create();
    const lastCenter = map.rooms[map.rooms.len - 1].center();
    ctx.registry.add(amulet, component.Position{ .vec = lastCenter });
    const index = @intFromEnum(resource.TileType.amulet);
    const sprite = component.Sprite{ .sheet = map.sheet, .index = index };
    ctx.registry.add(amulet, sprite);
    ctx.registry.add(amulet, component.Name{ .value = @tagName(.amulet) });
    ctx.registry.add(amulet, component.Item{});
    ctx.registry.add(amulet, component.Amulet{});
}
