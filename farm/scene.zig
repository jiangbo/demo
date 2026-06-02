const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");
const map = @import("map.zig");
const render = @import("system/render.zig");
const system = @import("system.zig");
const title = @import("title.zig");
const ui = @import("ui.zig");

const World = zhu.ecs.World;
const actor = component.actor;
const motion = component.motion;
const Target = component.ui.Target;
const Position = component.Position;

const initialTargetId: i32 = -1;

pub fn init(world: *World) void {
    std.log.info("scene init current={s}", .{@tagName(context.scene.current)});
    system.init();
    title.init();
    enterScene(world, context.scene.current);
}

pub fn deinit() void {}

pub fn update(world: *World, delta: f32) void {
    if (zhu.input.key.pressed(.X)) drawDebug = !drawDebug;

    const pauseKey = zhu.input.key.anyPressed(&.{ .ESCAPE, .P });
    if (ui.pause.active) {
        // 暂停时只更新覆盖菜单，保持底层农场画面静止。
        system.updatePause(world, delta);
        if (pauseKey) {
            ui.pause.active = false;
            return;
        }
        ui.pause.update(world);
        return;
    }

    if (context.scene.current == .farm and pauseKey) {
        ui.pause.active = true;
        return;
    }

    if (context.time.paused) return;

    const scaled = delta * context.time.scale;
    switch (context.scene.current) {
        .title => title.update(scaled),
        .farm => updateFarm(world, scaled),
    }

    applyScene(world);
}

pub fn draw(world: *World) void {
    switch (context.scene.current) {
        .title => title.draw(),
        .farm => drawFarm(world),
    }
    zhu.camera.mode = .window;
    if (ui.pause.active) ui.pause.draw();
    if (drawDebug) zhu.window.drawDebugInfo();
    zhu.camera.mode = .world;
}

fn updateFarm(world: *World, delta: f32) void {
    if (context.map.takePending()) |request| changeMap(world, request);

    if (context.ui.wantCapture()) {
        const player = world.getIdentity(actor.Player).?;
        world.getPtr(player, motion.Velocity).?.value = .zero;
        world.getPtr(player, actor.Actor).?.action = .idle;
        world.getPtr(player, Target).?.active = false;

        system.updateCapture(world, delta);
        ui.dialog.update(world);
        return;
    }

    system.update(world, delta);
    ui.toolbar.update();
    ui.dialog.update(world);
}

fn applyScene(world: *World) void {
    const previous = context.scene.current;
    context.scene.apply();

    const current = context.scene.current;
    if (previous == current) return;

    exitScene(previous);
    enterScene(world, current);
}

fn enterScene(world: *World, next: context.scene.Scene) void {
    switch (next) {
        .title => title.enter(),
        .farm => enterFarm(world),
    }
}

fn exitScene(previous: context.scene.Scene) void {
    switch (previous) {
        .title => title.exit(),
        .farm => {},
    }
}

fn enterFarm(world: *World) void {
    zhu.camera.scale = .square(2);
    const spawn = map.enter(world, .town, initialTargetId);
    factory.spawnPlayer(world, spawn);
    ui.toolbar.enter();
}

fn drawFarm(world: *World) void {
    map.drawBack();
    render.draw(world);
    map.drawFront();

    // 调试绘制碰撞层
    drawSolids();
    drawCollider(world);

    ui.draw(world);
}

var drawDebug: bool = true;

fn drawSolids() void {
    const tileSize = map.data.tileSize;
    for (map.physics.tiles, 0..) |solid, index| {
        if (!solid) continue;
        const position = map.data.tileIndexToWorld(index);
        zhu.batch.drawDebug(.init(position, tileSize));
    }

    for (map.physics.areas.items) |rect| zhu.batch.drawDebug(rect);
}

fn drawCollider(world: *zhu.ecs.World) void {
    const player = world.getIdentity(actor.Player).?;
    const position = world.get(player, Position).?;
    const collider = world.get(player, motion.Collider).?;
    const rect = zhu.Rect.init(
        position.add(collider.offset),
        collider.size,
    );
    zhu.batch.drawRect(rect, .{ .color = .rgba(0, 1, 0, 0.4) });
}

fn changeMap(world: *World, request: context.map.Transition) void {
    map.exit(world);
    const spawn = map.enter(world, request.target, request.targetId);

    const player = world.getIdentity(actor.Player).?;
    world.getPtr(player, Position).?.* = spawn;
    world.getPtr(player, motion.Velocity).?.value = .zero;
    world.getPtr(player, Target).?.active = false;
}
