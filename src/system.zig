const std = @import("std");
const engine = @import("engine.zig");
const component = @import("component.zig");
const resource = @import("resource.zig");

pub const StateEnum = enum { running, over, win, reset };
pub var deltaTime: usize = 0;

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
    renderPlayerHealth(ctx);
    renderItem(ctx);

    const state = ctx.registry.singletons().getConst(StateEnum);
    if (state == .over) {
        engine.drawText(400, 200, "Your quest has ended.", 40);
    }

    if (state == .win) {
        engine.drawText(440, 200, "You have won!", 40);
    }

    if (state == .win or state == .over) {
        deltaTime += engine.frameTime();
        if (deltaTime > 1000) deltaTime = 0 else if (deltaTime > 500) {
            engine.drawText(430, 450, "Press Enter to play again.", 28);
        }
        if (engine.isPressedEnter()) {
            ctx.registry.singletons().get(StateEnum).* = .reset;
        }
    }

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

fn renderPlayerHealth(ctx: *engine.Context) void {
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

fn renderItem(ctx: *engine.Context) void {
    const camera = ctx.registry.singletons().get(resource.Camera);
    const components = .{ component.Position, component.Item, component.Name };
    var view = ctx.registry.view(components, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const position = view.getConst(component.Position, entity);
        const name = view.getConst(component.Name, entity);
        if (camera.isVisible(position.vec)) {
            const x = (position.vec.x -| camera.x) * 32;
            const y = (position.vec.y -| camera.y) * 32 -| 20;
            engine.drawText(x, y, name.value, 15);
        }
    }
}

fn enemyMove(ctx: *engine.Context) void {
    const map = ctx.registry.singletons().get(resource.Map);

    var playerView = ctx.registry.view(.{ component.Position, component.Player }, .{});
    var playerIter = playerView.entityIterator();
    const playerEntity = playerIter.next().?;
    const playerPos = playerView.getConst(component.Position, playerEntity);

    const components = .{ component.Position, component.Enemy };
    var view = ctx.registry.view(components, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const position = view.get(component.Position, entity);

        if (position.vec.x == playerPos.vec.x) {
            if (position.vec.y + 1 == playerPos.vec.y or position.vec.y == playerPos.vec.y + 1) {
                const attack = component.Attack{ .attacker = entity, .victim = playerEntity };
                ctx.registry.add(ctx.registry.create(), attack);
                continue;
            }
        } else if (position.vec.y == playerPos.vec.y) {
            if (position.vec.x + 1 == playerPos.vec.x or position.vec.x == playerPos.vec.x + 1) {
                const attack = component.Attack{ .attacker = entity, .victim = playerEntity };
                ctx.registry.add(ctx.registry.create(), attack);
                continue;
            }
        }

        var newPos = position.vec;
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

fn getPlayerPosition(ctx: *engine.Context) component.Position {
    const components = .{ component.Position, component.Player };
    var playerView = ctx.registry.view(components, .{});
    var playerIter = playerView.entityIterator();
    const playerEntity = playerIter.next().?;
    return playerView.getConst(component.Position, playerEntity);
}

fn playerMove(ctx: *engine.Context) bool {
    const map = ctx.registry.singletons().get(resource.Map);
    const camera = ctx.registry.singletons().get(resource.Camera);

    const components = .{ component.Position, component.Player };
    var view = ctx.registry.view(components, .{});
    var iter = view.entityIterator();
    const player = iter.next().?;
    const position = view.get(component.Position, player);
    var newPos = getPlayerPosition(ctx).vec;

    var playerHealth = ctx.registry.get(component.Health, player);
    if (!engine.move(&newPos)) {
        playerHealth.current = @min(playerHealth.max, playerHealth.current + 1);
        return true;
    }

    const enemys = .{ component.Position, component.Enemy };
    var enemyView = ctx.registry.view(enemys, .{});
    var enemyIter = enemyView.entityIterator();
    while (enemyIter.next()) |enemy| {
        const enemyPos = enemyView.getConst(component.Position, enemy);
        if (newPos.equal(enemyPos.vec)) {
            const attackEntity = ctx.registry.create();
            const attack = component.Attack{ .attacker = player, .victim = enemy };
            ctx.registry.add(attackEntity, attack);
            return true;
        }
    }

    if (map.canEnter(newPos) and !newPos.equal(position.vec)) {
        position.* = component.Position{ .vec = newPos };
        camera.* = resource.Camera.init(newPos.x, newPos.y);
        return true;
    }
    return false;
}

fn combat(ctx: *engine.Context) void {
    var view = ctx.registry.view(.{component.Attack}, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const attack = view.getConst(entity);
        const health = ctx.registry.get(component.Health, attack.victim);
        health.current -|= 1;
        if (health.current == 0) {
            if (ctx.registry.has(component.Player, attack.victim)) {
                ctx.registry.singletons().get(StateEnum).* = .over;
            } else ctx.registry.destroy(attack.victim);
        }
        ctx.registry.destroy(entity);
    }
}

fn getItem(ctx: *engine.Context) void {
    const playerPosition = getPlayerPosition(ctx);

    const components = .{ component.Position, component.Item };
    var view = ctx.registry.view(components, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const position = view.getConst(component.Position, entity);
        if (position.vec.equal(playerPosition.vec)) {
            if (ctx.registry.has(component.Amulet, entity)) {
                ctx.registry.singletons().get(StateEnum).* = .win;
            }
            ctx.registry.destroy(entity);
        }
    }
}

pub fn runUpdateSystems(ctx: *engine.Context) void {
    if (ctx.registry.singletons().getConst(StateEnum) == .running) {
        if (playerMove(ctx)) {
            enemyMove(ctx);
            getItem(ctx);
        }
        combat(ctx);
    }
    render(ctx);
}
