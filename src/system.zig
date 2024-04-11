const std = @import("std");
const engine = @import("engine.zig");
const component = @import("component.zig");
const resource = @import("resource.zig");

fn render(ctx: *engine.Context) void {
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
        if (camera.isVisible(position.vec)) {
            const x = position.vec.x -| camera.x;
            const y = position.vec.y -| camera.y;
            sprite.sheet.drawTile(sprite.index, x, y);
        }
    }

    engine.drawFPS(10, 10);
}

fn enemyMove(ctx: *engine.Context) void {
    const map = ctx.registry.singletons().get(resource.Map);

    const components = .{ component.Position, component.Enemy };
    var view = ctx.registry.view(components, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const position = view.get(component.Position, entity);
        var newPos = position.*.vec;
        switch (engine.randomValue(0, 4)) {
            0 => newPos.y -|= 1,
            1 => newPos.y += 1,
            2 => newPos.x -|= 1,
            3 => newPos.x += 1,
            else => unreachable,
        }

        if (map.canEnter(newPos)) {
            position.vec = newPos;
        }
    }
}

fn playerMove(ctx: *engine.Context) bool {
    const map = ctx.registry.singletons().get(resource.Map);
    const camera = ctx.registry.singletons().get(resource.Camera);

    const components = .{ component.Position, component.Player };
    var view = ctx.registry.view(components, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const position = view.get(component.Position, entity);
        var newPos = position.*.vec;
        engine.move(&newPos);

        if (map.canEnter(newPos) and !newPos.equal(position.vec)) {
            position.* = component.Position{ .vec = newPos };
            camera.* = resource.Camera.init(newPos.x, newPos.y);
            return true;
        }
    }
    return false;
}

fn collision(ctx: *engine.Context) void {
    const player = .{ component.Position, component.Player };
    var view = ctx.registry.view(player, .{});
    var iter = view.entityIterator();
    var playerPos: component.Position = undefined;
    while (iter.next()) |entity| {
        playerPos = view.getConst(component.Position, entity);
    }

    const enemy = .{ component.Position, component.Enemy };
    view = ctx.registry.view(enemy, .{});
    iter = view.entityIterator();
    while (iter.next()) |entity| {
        const position = view.getConst(component.Position, entity);
        if (playerPos.vec.equal(position.vec)) {
            ctx.registry.destroy(entity);
        }
    }
}

pub fn runUpdateSystems(context: *engine.Context) void {
    if (playerMove(context)) {
        enemyMove(context);
    }
    collision(context);
    render(context);
}
