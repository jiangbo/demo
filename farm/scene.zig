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

const MapFade = struct {
    const Phase = enum { out, in };

    phase: ?Phase = null,
    timer: zhu.Timer = .init(0.15),
};

const Scene = union(enum) { title, play: ?u8 };

var world: World = undefined;
var allocator: zhu.Allocator = undefined;
var canvas: zhu.graphics.RenderTarget = .{};
var mapFade: MapFade = .{};
var debug = false;
var current: Scene = .title;
var pending: ?Scene = null;

pub fn init(allocator_: zhu.Allocator) void {
    allocator = allocator_;

    // 组合根只负责装配顺序，具体玩法仍放在各自模块里。
    context.init();
    world = World.init(allocator.raw);

    // 存档状态先就位，UI 只持有这份长期有效的槽位切片。
    save.init();
    ui.init(&save.slots);
    title.init();
    map.init();
    factory.init();

    canvas = zhu.graphics.createRenderTarget(zhu.window.size);

    // 有独立资源或初始状态的系统在进入首个场景前完成初始化。
    system.time.init();
    system.light.init();
    enterScene(current);
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

    switch (current) {
        .title => if (title.update(delta)) |request| {
            switch (request) {
                .start => pending = .{ .play = null },
                .load => |slot| pending = .{ .play = slot },
            }
        },
        .play => if (ui.update()) |req| {
            return updatePlayUi(req);
        } else updatePlay(delta),
    }
}

pub fn draw() void {
    const clearColor: zhu.Color = .rgb(0.23, 0.31, 0.27);
    switch (current) {
        .title => {
            zhu.batch.useTarget(clearColor, .{});
            title.draw();
            if (debug) drawDebug();
        },
        .play => {
            zhu.batch.useTarget(clearColor, .{ .target = &canvas });
            drawPlay();
            if (debug) drawDebug();

            zhu.batch.useTarget(clearColor, .{});
            zhu.batch.drawImage(canvas.image, .zero, .{
                .camera = .window,
            });
            if (mapFade.phase) |phase| drawMapFade(phase);
        },
    }
}

fn drawDebug() void {
    const total = world.entities.versions.items.len;

    var entityBuffer: [32]u8 = undefined;
    var componentBuffer: [32]u8 = undefined;
    const rows = [_]zhu.debug.Row{.{
        .label = "世界",
        .left = zhu.format(&entityBuffer, "实体 {}/{}", .{
            total - world.entities.deletedCount,
            total,
        }),
        .right = zhu.format(&componentBuffer, "组件 {}", .{
            world.map.count(),
        }),
    }};
    zhu.debug.draw(&rows);
}

fn updatePlayUi(req: ui.UiRequest) void {
    switch (req) {
        .block => {},
        .title => pending = .title,
        .rest => |hours| context.clock.restHours = hours,
        .save => |slot| {
            if (!save.saveSlot(&world, slot)) {
                ui.showMessage(.{ .text = "保存失败", .fail = true });
                return;
            }
            ui.showMessage(.{ .text = "保存成功", .fail = false });
        },
        .load => |slot| {
            if (!save.loadSlot(&world, slot)) {
                ui.showMessage(.{ .text = "读取失败", .fail = true });
                return;
            }
            ui.close();
        },
    }
}

fn updatePlay(delta: f32) void {
    // 农场主循环顺序在这里显式编排，新增系统需要在这里确定位置。
    if (pending != null) return;
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
    const next = pending orelse return;
    ui.close();
    switch (current) {
        .title => title.exit(),
        .play => {
            mapFade = .{};
            context.map.pending = null;
            map.exit(&world);
        },
    }
    current, pending = .{ next, null };
    enterScene(current);
}

fn enterScene(next: Scene) void {
    switch (next) {
        .title => title.enter(),
        .play => |slot| enterPlay(slot),
    }
}

fn enterPlay(loadSlot: ?u8) void {
    zhu.camera.main.scale = .square(2);
    if (loadSlot == null) {
        // 新游戏重置世界级状态；读档会在基础地图创建后覆盖状态。
        context.clock.reset();
        context.map.resetStates();
    }

    map.enter(&world, .exterior, -1);
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
        if (!save.loadSlot(&world, slot)) {
            pending = .title;
            return;
        }
    }
    zhu.audio.playMusic("audio/01_spring_journey.ogg");
}

fn cameraFollowPlayer(delta: f32) void {
    const player = world.getIdentity(actor.Player).?;
    const position = world.get(player, Position).?;

    // 平滑值交给引擎相机限制范围，这里只表达速度随 delta 缩放。
    const speed: f32 = 9;
    zhu.camera.smoothFollow(position, speed * delta);
    zhu.camera.roundPosition();
}

fn drawPlay() void {
    map.drawBack();
    system.render.draw(&world);
    map.drawFront();

    system.control.draw(&world);
    system.light.draw(&world);

    zhu.camera.push(.window);
    defer zhu.camera.pop();
    system.time.draw();
    ui.draw(&world);
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
