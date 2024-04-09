const std = @import("std");
const ecs = @import("ecs");
const Context = @import("context.zig").Context;
const World = @import("world.zig").World;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var registry = ecs.Registry.init(gpa.allocator());
    var context = Context.init(gpa.allocator(), &registry);
    defer context.deinit();

    var world = World.init(context);
    world.run();

    // var mapBuilder = game.MapBuilder.init();
    // defer mapBuilder.map.tilemap.deinit();

    // while (!ray.WindowShouldClose()) {
    //     mapBuilder.update();
    //     mapBuilder.render();
    // }
}
