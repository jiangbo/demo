const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");
const inventory = @import("inventory.zig");
const interact = @import("interact.zig");
const map = @import("map.zig");
const save = @import("save.zig");
const title = @import("title.zig");
const ui = @import("ui.zig");

const system = struct {
    const animation = @import("system/animation.zig");
    const control = @import("system/control.zig");
    const farm = @import("system/farm.zig");
    const life = @import("system/life.zig");
    const light = @import("system/light.zig");
    const movement = @import("system/movement.zig");
    const pickup = @import("system/pickup.zig");
    const render = @import("system/render.zig");
    const sound = @import("system/sound.zig");
    const time = @import("system/time.zig");
    const transition = @import("system/transition.zig");
    const wander = @import("system/wander.zig");
};

const World = zhu.ecs.World;
const actor = component.actor;
const Position = component.Position;

const initialTargetId: i32 = -1;
const followSpeed: f32 = 9;

const MapFade = struct {
    const Phase = enum { out, in };

    phase: ?Phase = null,
    timer: zhu.Timer = .init(0.15),
};

var world: World = undefined;
var allocator: zhu.Allocator = undefined;
var canvas: zhu.graphics.RenderTarget = .{};
var mapFade: MapFade = .{};
var debug = false;

pub fn init(allocator_: zhu.Allocator) void {
    allocator = allocator_;

    // 组合根只负责装配顺序，具体玩法仍放在各自模块里。
    context.init();
    world = World.init(allocator.raw);

    // UI 和数据模块先就位，后面的入场流程会立即使用它们。
    ui.init();
    title.init();
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
    if (zhu.key.released(.X)) debug = !debug;

    context.input.mouseCaptured = false;
    applyScene();

    if (updateMapFade(delta)) return;

    switch (context.scene.current) {
        .title => if (title.update(delta)) |request| {
            handleRequest(request);
        },
        .farm => {
            if (ui.overlay.update(&world)) |result| {
                switch (result) {
                    .block => {},
                    .title => context.scene.request(.title),
                    .rest => |hours| context.clock.restHours = hours,
                }
                return;
            }
            updateFarm(delta);
        },
    }
}

pub fn draw() void {
    const clearColor: zhu.Color = .rgb(0.23, 0.31, 0.27);
    switch (context.scene.current) {
        .title => {
            zhu.batch.useTarget(clearColor, .{});
            title.draw();
            if (debug) zhu.debug.draw();
        },
        .farm => {
            zhu.batch.useTarget(clearColor, .{ .target = &canvas });
            drawFarm();
            if (debug) zhu.debug.draw();

            zhu.batch.useTarget(clearColor, .{});
            zhu.batch.drawImage(canvas.image, .zero, .{
                .camera = .window,
            });
            if (mapFade.phase) |phase| drawMapFade(phase);
        },
    }
}

fn updateFarm(delta: f32) void {
    // 农场主循环顺序在这里显式编排，新增系统需要在这里确定位置。
    if (context.scene.pending != null) return;
    if (context.clock.paused) return;

    // 已提交的切图请求先进入过渡，不再瞬时换图。
    if (context.map.pending != null) {
        mapFade.phase = .out;
        mapFade.timer.restart();
        return;
    }

    // 时间先推进，地图跨天逻辑和灯光都依赖本帧最新时间事件。
    system.time.update(&world, delta);
    map.update(&world);
    system.light.update(&world);

    // 输入先写入意图，移动系统统一结算位置和碰撞。
    inventory.update();
    system.control.update(&world);
    system.life.update(&world, delta);
    system.wander.update(&world, delta);
    system.movement.update(&world, delta);

    // 控制系统可能生成拾取物，所以拾取放在控制之后。
    system.pickup.update(&world, delta);

    // 按 F 的处理、相机跟随、动画和排序都读取本帧已结算的位置。
    ui.notice.update(delta);
    interact.update(&world);
    cameraFollowPlayer(delta);
    system.animation.update(&world, delta);
    system.farm.update(&world);
    system.render.update(&world);

    // 本帧世界结算完后记录下一帧是否需要切图。
    system.transition.update(&world);

    // 音效最后播放，统一消费本帧前面系统发出的 SoundPlay 事件。
    system.sound.update(&world);
}

fn updateMapFade(delta: f32) bool {
    const phase = mapFade.phase orelse return false;
    if (mapFade.timer.updateRunning(delta)) return true;

    switch (phase) {
        .out => {
            map.change(&world, context.map.takePending().?);
            mapFade.phase = .in;
            mapFade.timer.restart();
        },
        .in => mapFade = .{},
    }
    return true;
}

fn applyScene() void {
    const previous = context.scene.current;
    context.scene.apply();

    const current = context.scene.current;
    if (previous == current) return;

    ui.overlay.close();
    switch (previous) {
        .title => title.exit(),
        .farm => {
            mapFade = .{};
            context.map.pending = null;
            map.exit(&world);
        },
    }
    enterScene(current);
}

fn handleRequest(request: title.Request) void {
    switch (request) {
        .start => context.scene.requestNewGame(),
        .load => |slot| context.scene.requestLoad(slot),
    }
}

fn enterScene(next: context.scene.Scene) void {
    switch (next) {
        .title => title.enter(),
        .farm => enterFarm(),
    }
}

fn enterFarm() void {
    zhu.camera.main.scale = .square(2);
    const loadSlot = context.scene.takeLoadSlot();
    if (loadSlot == null) {
        // 新游戏重置世界级状态；读档会在基础地图创建后覆盖状态。
        context.clock.reset();
        context.map.resetStates();
    }

    map.enter(&world, .exterior, initialTargetId);
    inventory.reset();
    if (loadSlot == null) {
        _ = inventory.add(.hoe, 1);
        _ = inventory.add(.water, 1);
        _ = inventory.add(.pickaxe, 1);
        _ = inventory.add(.axe, 1);
        _ = inventory.add(.sickle, 1);
    }

    if (loadSlot) |slot| {
        // 存档恢复依赖已经存在的 world/map/player 基础结构。
        save.loadSlot(&world, slot) catch |err| {
            std.log.err("load slot {} failed when entering farm: {}", .{
                slot,
                err,
            });
            context.scene.request(.title);
            return;
        };
    }
    zhu.audio.playMusic("audio/01_spring_journey.ogg");
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

    system.control.draw(&world);
    system.light.draw(&world);

    zhu.camera.push(.window);
    defer zhu.camera.pop();
    system.time.draw();
    ui.draw(&world);
    ui.overlay.draw();
}

fn drawMapFade(phase: MapFade.Phase) void {
    const alpha = switch (phase) {
        .out => mapFade.timer.progress(),
        .in => 1 - mapFade.timer.progress(),
    };

    zhu.camera.push(.window);
    defer zhu.camera.pop();

    const rect = zhu.Rect.init(.zero, zhu.window.size);
    zhu.batch.drawRect(rect, .{ .color = .gray(0, alpha) });
}
