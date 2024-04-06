const std = @import("std");
const Context = @import("context.zig").Context;
const World = @import("world.zig").World;
const ray = @import("raylib.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var context = Context.init(gpa.allocator());
    defer context.deinit();

    var world = World.init(context);

    while (!ray.WindowShouldClose()) {
        world.run();
    }

    // var mapBuilder = game.MapBuilder.init();
    // defer mapBuilder.map.tilemap.deinit();

    // while (!ray.WindowShouldClose()) {
    //     mapBuilder.update();
    //     mapBuilder.render();
    // }
}
