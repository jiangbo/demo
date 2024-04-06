const std = @import("std");
const ecs = @import("ecs");
const Context = @import("context.zig").Context;
const game = @import("game.zig");

pub fn spawn(context: *Context) void {
    const builder = game.MapBuilder.init();
    context.registry.singletons().add(builder.map);
}

pub fn deinit(context: *Context) void {
    context.registry.singletons().deinit();
}
