const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");
const map = @import("map.zig");
const save = @import("save.zig");
const ui = @import("ui.zig");

const system = struct {
    const animation = @import("system/animation.zig");
    const control = @import("system/control.zig");
    const light = @import("system/light.zig");
    const movement = @import("system/movement.zig");
    const pickup = @import("system/pickup.zig");
    const render = @import("system/render.zig");
    const sound = @import("system/sound.zig");
    const talk = @import("system/talk.zig");
    const time = @import("system/time.zig");
    const transition = @import("system/transition.zig");
    const wander = @import("system/wander.zig");
};

const World = zhu.ecs.World;
const actor = component.actor;
const motion = component.motion;
const Target = component.ui.Target;
const Position = component.Position;

const initialTargetId: i32 = -1;
const followSpeed: f32 = 9;

var world: World = undefined;
var canvas: zhu.graphics.RenderTarget = .{};

pub fn init() void {
    // 组合根只负责装配顺序，具体玩法仍放在各自模块里。
    context.init();
    world = .init(zhu.assets.allocator);

    // UI 和数据模块先就位，后面的入场流程会立即使用它们。
    ui.init();
    map.init();
    factory.init();

    canvas = zhu.graphics.createRenderTarget(zhu.window.size);
    std.log.info("scene init current={s}", .{@tagName(context.scene.current)});

    // 有独立资源或初始状态的系统在进入首个场景前完成初始化。
    system.time.init();
    system.light.init();
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
        if (context.scene.current == .farm) system.sound.update(&world);
        ui.save_slot.update(&world);
        if (ui.save_slot.takeClosePauseAfterLoad()) ui.pause.active = false;
        applyScene();
        return;
    }

    if (ui.pause.active) {
        // 暂停时只更新覆盖菜单，保持底层农场画面静止。
        system.sound.update(&world);
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
    // 农场主循环顺序在这里显式编排，新增系统需要在这里确定位置。
    // 上一帧提交的切图请求先落地，避免旧地图实体继续参与本帧逻辑。
    if (context.map.takePending()) |request| changeMap(request);

    // 时间先推进，地图跨天逻辑和灯光都依赖本帧最新时间事件。
    system.time.update(&world, delta);
    map.update(&world);
    system.light.update(&world);

    // 输入先写入意图，移动系统统一结算位置和碰撞。
    ui.toolbar.update();
    system.control.update(&world);
    system.wander.update(&world, delta);
    system.movement.update(&world, delta);

    // 触发器必须读取移动后的玩家位置；真正切图放到下一帧开头。
    system.transition.update(&world);

    // 控制系统可能生成拾取物，所以拾取放在控制之后。
    system.pickup.update(&world);

    // 对话距离、相机跟随、动画和排序都读取本帧已结算的位置。
    system.talk.update(&world);
    cameraFollowPlayer(delta);
    system.animation.update(&world, delta);
    system.render.update(&world);

    // 音效最后播放，统一消费本帧前面系统发出的 SoundPlay 事件。
    system.sound.update(&world);
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
        // 新游戏重置世界级状态；读档会在基础地图创建后覆盖状态。
        context.clock.reset();
        context.map.resetStates();
    }

    // 地图先生成静态对象和触发器，玩家随后由场景统一创建。
    const spawn = map.enter(&world, .exterior, initialTargetId);
    factory.spawnPlayer(&world, spawn);
    ui.toolbar.enter();

    if (loadSlot) |slot| {
        // 存档恢复依赖已经存在的 world/map/player 基础结构。
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

fn cameraFollowPlayer(delta: f32) void {
    const player = world.getIdentity(actor.Player).?;
    const position = world.get(player, Position).?;

    // 平滑值交给引擎相机限制范围，这里只表达速度随 delta 缩放。
    zhu.camera.smoothFollow(position, followSpeed * delta);
    zhu.camera.roundPosition();
}

fn drawFarm() void {
    map.drawBack();
    system.render.draw(&world);
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
    const spawn = map.change(&world, request.target, request.targetId);

    const player = world.getIdentity(actor.Player).?;
    world.getPtr(player, Position).?.* = spawn;
    world.getPtr(player, motion.Velocity).?.value = .zero;
    world.getPtr(player, Target).?.active = false;
}
