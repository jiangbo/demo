const std = @import("std");

const camera = @import("../camera.zig");
const ecs = @import("ecs.zig");

pub fn render(w: *ecs.Registry) void {
    var view = w.view(.{ ecs.c.Texture, ecs.c.Position }, .{});
    while (view.next()) |entity| {
        const texture = view.get(entity, ecs.c.Texture);
        const position = view.get(entity, ecs.c.Position);
        camera.draw(texture, position);
    }
}
