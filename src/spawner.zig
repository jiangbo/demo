const std = @import("std");
const ray = @import("raylib.zig");
const Context = @import("context.zig").Context;
const component = @import("component.zig");
const asset = @import("asset.zig");
const game = @import("game.zig");

pub fn spawn(ctx: *Context) void {
    // const builder = game.MapBuilder.init();
    // context.registry.singletons().add(builder.map);
    const imageEntity = ctx.registry.create();
    const image = component.Image{ .texture = asset.dungeon };
    ctx.registry.add(imageEntity, image);
}

pub fn deinit(_: *Context) void {
    // var map = context.registry.singletons().get(game.Map);
    // map.tilemap.deinit();
}
