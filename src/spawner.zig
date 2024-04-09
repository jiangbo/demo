const std = @import("std");
const component = @import("component.zig");
const asset = @import("asset.zig");
const resource = @import("resource.zig");
const engine = @import("engine.zig");

pub fn spawn(ctx: *engine.Context) void {
    var start = std.time.Timer.start() catch unreachable;

    const map = resource.Map.init(asset.dungeon);
    ctx.registry.singletons().add(map);

    spawnPlayer(ctx, map);

    const center = map.rooms[0].center();
    const camera = resource.Camera.init(center.x, center.y);
    ctx.registry.singletons().add(camera);

    std.log.info("Spawning took {}ms", .{start.read() / std.time.ns_per_ms});
}

fn spawnPlayer(ctx: *engine.Context, map: resource.Map) void {
    const player = ctx.registry.create();
    const center = map.rooms[0].center();
    ctx.registry.add(player, component.Position.fromVec(center));
    const index = @intFromEnum(resource.TileType.player);
    const sprite = component.Sprite{ .sheet = map.sheet, .index = index };
    ctx.registry.add(player, sprite);
}
