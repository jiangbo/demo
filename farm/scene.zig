const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");
const map = @import("map.zig");
const render = @import("system/render.zig");
const save = @import("save.zig");
const system = @import("system.zig");
const ui = @import("ui.zig");

const World = zhu.ecs.World;
const actor = component.actor;
const motion = component.motion;
const Target = component.ui.Target;
const Position = component.Position;

const initialTargetId: i32 = -1;

var world: World = undefined;
var canvas: zhu.graphics.RenderTarget = .{};

pub fn init() void {
    context.init();
    world = .init(zhu.assets.allocator);
    ui.init();
    map.init();
    factory.init();
    canvas = zhu.graphics.createRenderTarget(zhu.window.size);
    std.log.info("scene init current={s}", .{@tagName(context.scene.current)});
    system.init();
    enterScene(context.scene.current);
}

pub fn deinit() void {
    map.deinit();
    context.deinit();
    ui.deinit();
    world.deinit();
}

pub fn update(delta: f32) void {
    context.input.mouseCaptured = false;

    const pauseKey = zhu.key.anyPressed(&.{ .ESCAPE, .P });
    if (ui.save_slot.active) {
        // 槽位选择是顶层覆盖层，底下的标题或暂停菜单都不再吃输入。
        if (context.scene.current == .farm) system.updatePause(&world, delta);
        ui.save_slot.update(&world);
        if (ui.save_slot.takeClosePauseAfterLoad()) ui.pause.active = false;
        applyScene();
        return;
    }

    if (ui.pause.active) {
        // 暂停时只更新覆盖菜单，保持底层农场画面静止。
        system.updatePause(&world, delta);
        if (pauseKey) {
            ui.pause.active = false;
            return;
        }
        ui.pause.update();
        applyScene();
        return;
    }

    if (context.scene.current == .farm and pauseKey) {
        ui.pause.enter(false);
        return;
    }

    if (context.scene.current == .farm and context.clock.paused) {
        applyScene();
        return;
    }

    switch (context.scene.current) {
        .title => ui.title.update(delta),
        // 速度倍率只影响可游玩的农场场景，不影响标题动画。
        .farm => updateFarm(delta * context.clock.speed),
    }

    applyScene();
}

pub fn draw() void {
    const clearColor: zhu.Color = .rgb(0.23, 0.31, 0.27);
    switch (context.scene.current) {
        .title => {
            zhu.batch.useTarget(clearColor, .{});
            ui.title.draw();
            drawOverlay();
        },
        .farm => {
            zhu.batch.useTarget(clearColor, .{ .target = &canvas });
            drawFarm();
            drawOverlay();

            zhu.batch.useTarget(clearColor, .{});
            zhu.batch.drawImage(canvas.image, .zero, .{
                .mode = .window,
            });
        },
    }
}

fn drawOverlay() void {
    zhu.camera.mode = .window;
    if (ui.pause.active) ui.pause.draw();
    if (ui.save_slot.active) ui.save_slot.draw();
    zhu.camera.mode = .world;
}

fn updateFarm(delta: f32) void {
    if (context.map.takePending()) |request| changeMap(request);

    ui.toolbar.update();
    system.update(&world, delta);
}

fn applyScene() void {
    const previous = context.scene.current;
    context.scene.apply();

    const current = context.scene.current;
    if (previous == current) return;

    ui.pause.active = false;
    switch (previous) {
        .title => ui.title.exit(),
        .farm => map.exit(&world),
    }
    enterScene(current);
}

fn enterScene(next: context.scene.Scene) void {
    switch (next) {
        .title => ui.title.enter(),
        .farm => enterFarm(),
    }
}

fn enterFarm() void {
    zhu.camera.scale = .square(2);
    const loadSlot = context.scene.takeLoadSlot();
    if (loadSlot == null) {
        context.clock.reset();
        context.map.resetStates();
    }

    const spawn = map.enter(&world, .exterior, initialTargetId);
    factory.spawnPlayer(&world, spawn);
    ui.toolbar.enter();

    if (loadSlot) |slot| {
        save.loadSlot(&world, slot) catch |err| {
            std.log.err("load slot {} failed when entering farm: {}", .{
                slot,
                err,
            });
            context.scene.request(.title);
        };
    }
    zhu.audio.playMusic("assets/audio/01_spring_journey.ogg");
}

fn drawFarm() void {
    map.drawBack();
    render.draw(&world);
    map.drawFront();

    // 调试绘制碰撞层
    drawSolids();
    drawShape();

    ui.draw(&world);
}

fn drawSolids() void {
    const tileSize = map.data.tileSize;
    for (map.spatial.tiles, 0..) |marks, index| {
        if (!map.spatial.hasAnyBlock(marks)) continue;
        const position = map.data.tileIndexToWorld(index);
        zhu.batch.drawDebug(.init(position, tileSize));
    }

    for (map.spatial.areas.items) |rect| zhu.batch.drawDebug(rect);
}

fn drawShape() void {
    const player = world.getIdentity(actor.Player).?;
    const position = world.get(player, Position).?;
    const body = world.get(player, motion.Shape).?;
    const shape = body.move(position);
    switch (shape) {
        .rect => |r| zhu.batch.drawRect(r, .{
            .color = .rgba(0, 1, 0, 0.4),
        }),
        .circle => |c| zhu.batch.drawCircle(c.center, .{
            .size = .xy(c.radius * 2, c.radius * 2),
            .anchor = zhu.Vector2.center,
            .color = .rgba(0, 1, 0, 0.4),
        }),
    }
}

fn changeMap(request: context.map.Transition) void {
    map.exit(&world);
    const spawn = map.enter(&world, request.target, request.targetId);

    const player = world.getIdentity(actor.Player).?;
    world.getPtr(player, Position).?.* = spawn;
    world.getPtr(player, motion.Velocity).?.value = .zero;
    world.getPtr(player, Target).?.active = false;
}
