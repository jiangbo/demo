const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");
const map = @import("map.zig");
const title = @import("title.zig");
const dialog = @import("dialog.zig");
const toolbar = @import("toolbar.zig");

const World = zhu.ecs.World;
const actor = component.actor;
const motion = component.motion;
const ui = component.ui;
const Position = component.Position;

const initialTargetId: i32 = -1;

const system = struct {
    const animation = @import("system/animation.zig");
    const camera = @import("system/camera.zig");
    const control = @import("system/control.zig");
    const crop = @import("system/crop.zig");
    const talk = @import("system/talk.zig");
    const movement = @import("system/movement.zig");
    const pickup = @import("system/pickup.zig");
    const render = @import("system/render.zig");
    const light = @import("system/light.zig");
    const target = @import("system/target.zig");
    const time = @import("system/time.zig");
    const tool = @import("system/tool.zig");
    const transition = @import("system/transition.zig");
    const wander = @import("system/wander.zig");
};

pub fn init(world: *World) void {
    std.log.info("scene init current={s}", .{@tagName(context.scene.current)});
    system.time.init();
    if (context.scene.current == .farm) enterFarm(world);
}

pub fn deinit() void {}

pub fn update(world: *World, delta: f32) void {
    if (zhu.input.key.pressed(.X)) drawDebug = !drawDebug;

    if (context.time.paused) return;

    const scaled = delta * context.time.scale;
    switch (context.scene.current) {
        .title => title.update(scaled),
        .farm => updateFarm(world, scaled),
    }

    const previous = context.scene.current;
    context.scene.apply();
    if (previous != .farm and context.scene.current == .farm) enterFarm(world);
}

pub fn draw(world: *World) void {
    switch (context.scene.current) {
        .title => title.draw(),
        .farm => drawFarm(world),
    }
}

fn updateFarm(world: *World, delta: f32) void {
    if (context.map.takePending()) |request| changeMap(world, request);

    system.time.update(world, delta);
    system.control.update(world);
    system.wander.update(world, delta);
    system.movement.update(world, delta);
    system.transition.update(world);
    system.animation.update(world, delta);
    system.crop.update(world, delta);
    system.render.update(world);
    system.pickup.update(world);

    if (context.ui.wantCapture()) {
        const player = world.getIdentity(actor.Player).?;
        world.getPtr(player, ui.Target).?.active = false;
        dialog.update(world);
        return;
    }

    system.talk.update(world);
    system.camera.update(world);
    system.target.update(world);
    system.tool.update(world);
    toolbar.update();
    dialog.update(world);
}

fn enterFarm(world: *World) void {
    const spawn = map.enter(world, .town, initialTargetId);
    factory.spawnPlayer(world, spawn);
    toolbar.enter();
}

fn drawFarm(world: *World) void {
    map.drawBack();
    system.render.draw(world);
    map.drawFront();
    system.target.draw(world);

    // 调试绘制碰撞层
    drawSolids();
    drawCollider(world);

    zhu.camera.mode = .window;
    system.light.draw();
    system.time.draw();
    toolbar.draw();
    dialog.draw(world);
    if (drawDebug) zhu.window.drawDebugInfo();
    zhu.camera.mode = .world;
}

var drawDebug: bool = true;

fn drawSolids() void {
    const tileSize = map.data.tileSize;
    for (map.physics.tiles, 0..) |solid, index| {
        if (!solid) continue;
        const position = map.data.tileIndexToWorld(index);
        zhu.batch.debugDraw(.init(position, tileSize));
    }

    for (map.physics.areas.items) |rect| zhu.batch.debugDraw(rect);
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
    world.getPtr(player, ui.Target).?.active = false;
}
