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

    renderNameAndHealty(ctx);
    renderHealth(ctx);

    engine.drawFPS(10, 10);
}

fn renderNameAndHealty(ctx: *engine.Context) void {
    const camera = ctx.registry.singletons().get(resource.Camera);
    const coms = .{ component.Position, component.Name, component.Health };
    var view = ctx.registry.view(coms, .{});
    var iter = view.entityIterator();
    var buffer: [50]u8 = undefined;
    while (iter.next()) |entity| {
        const position = view.getConst(component.Position, entity);
        const name = view.getConst(component.Name, entity);
        const health = view.getConst(component.Health, entity);
        const text = std.fmt.bufPrintZ(&buffer, "{s}: {}/{}", //
            .{ name.value, health.current, health.max }) catch unreachable;

        if (camera.isVisible(position.vec)) {
            const x = (position.vec.x -| camera.x) * 32 -| 18;
            const y = (position.vec.y -| camera.y) * 32 -| 20;
            engine.drawText(x, y, text, 15);
        }
    }
}

fn renderHealth(ctx: *engine.Context) void {
    const components = .{ component.Player, component.Health };
    var view = ctx.registry.view(components, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const health = view.getConst(component.Health, entity);
        var buffer: [50]u8 = undefined;
        const text = std.fmt.bufPrintZ(&buffer, "Health: {}/{}", //
            .{ health.current, health.max }) catch unreachable;
        engine.drawText(500, 10, text, 28);
    }
    engine.drawText(350, 40, "Explore the Dungeon. A/S/D/W to move.", 28);
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
        var newPos = position.vec;
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
