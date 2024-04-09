const std = @import("std");
const engine = @import("engine.zig");
const component = @import("component.zig");
const resource = @import("resource.zig");

fn renderSystem(ctx: *engine.Context) void {
    engine.beginDrawing();
    defer engine.endDrawing();
    engine.clearBackground();

    const map = ctx.registry.singletons().get(resource.Map);
    const camera = ctx.registry.singletons().get(resource.Camera);

    for (0..camera.height) |y| {
        for (0..camera.width) |x| {
            const tile = map.indexTile(x + camera.x, y + camera.y);
            map.sheet.drawTile(@intFromEnum(tile), x, y);
        }
    }

    const components = .{ component.Position, component.Sprite };
    var view = ctx.registry.view(components, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const position = view.getConst(component.Position, entity);
        const sprite = view.getConst(component.Sprite, entity);
        const x = position.x -| camera.x;
        const y = position.y -| camera.y;
        sprite.sheet.drawTile(sprite.index, x, y);
    }

    engine.drawFPS(10, 10);
}

pub fn runUpdateSystems(context: *engine.Context) void {
    renderSystem(context);
}
