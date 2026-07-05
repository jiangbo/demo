const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const factory = @import("factory.zig");
const input = @import("input.zig");
const map = @import("map.zig");
const player = @import("player.zig");
const storage = @import("storage.zig");
const system = @import("system/system.zig");
const title = @import("title.zig");
const ui = @import("ui.zig");

const resource = struct {
    const Clock = @import("resource/Clock.zig");
    const Inventory = @import("resource/Inventory.zig");
    const Notice = @import("resource/Notice.zig");
    const Speed = @import("resource/Speed.zig");
};

const World = zhu.ecs.World;
const actor = component.actor;
const Transition = component.map.Transition;

const MapFade = struct {
    const Phase = enum { out, in };

    phase: ?Phase = null,
    timer: zhu.Timer = .init(0.15),
};

const Scene = union(enum) { title, play: ?u8 };

pub var world: World = undefined;
var allocator: zhu.Allocator = undefined;
var canvas: zhu.graphics.RenderTarget = .{};
var mapFade: MapFade = .{};
var current: Scene = .title;
var pending: ?Scene = null;
var config: storage.Config = .{};

pub fn init(allocator_: zhu.Allocator) void {
    allocator = allocator_;

    world = World.init(allocator.raw);
    world.entity = world.createEntity();
    world.add(world.entity, resource.Clock{});
    world.add(world.entity, resource.Inventory{});
    world.add(world.entity, resource.Notice{});
    world.add(world.entity, resource.Speed{});

    // 存档状态先就位，UI 只持有这份长期有效的槽位切片。
    config = storage.init(&world);
    ui.init(.{ .slots = storage.slots(), .config = &config });
    title.init();
    map.init(allocator);

    canvas = zhu.graphics.createRenderTarget(zhu.window.size);

    system.init();
    enterScene(current);
}

pub fn deinit() void {
    switch (current) {
        .title => {},
        .play => {
            const clock = world.getPtr(world.entity, resource.Clock).?;
            map.exit(&world, clock.day);
        },
    }
    map.deinit();
    ui.deinit();
    world.deinit();
}

pub fn update(delta: f32) void {
    storage.update(&world, config);

    input.mouseCaptured = false;
    applyScene();

    if (updateMapFade(delta)) return;

    switch (current) {
        .title => if (title.update(delta)) |req| {
            switch (req) {
                .start => pending = .{ .play = null },
                .load => |slot| pending = .{ .play = slot },
            }
        },
        .play => if (ui.update(&world, delta)) |req| {
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
        },
        .play => {
            zhu.batch.useTarget(clearColor, .{ .target = &canvas });
            drawPlay();

            zhu.batch.useTarget(clearColor, .{});
            zhu.batch.drawImage(canvas.image, .zero, .{
                .camera = .window,
            });
            if (mapFade.phase) |phase| drawMapFade(phase);
        },
    }
}

fn updatePlayUi(req: ui.Request) void {
    switch (req) {
        .block => {},
        .title => pending = .title,
        .save => |slot| {
            if (!savePlay(slot)) {
                ui.showMessage(.{ .text = "保存失败", .fail = true });
                return;
            }
            ui.showMessage(.{ .text = "保存成功", .fail = false });
        },
        .load => |slot| {
            if (!loadPlay(slot)) {
                ui.showMessage(.{ .text = "读取失败", .fail = true });
                return;
            }
            ui.close();
        },
    }
}

fn updatePlay(delta: f32) void {
    const clock = world.getPtr(world.entity, resource.Clock).?;

    // 农场主循环顺序在这里显式编排，新增系统需要在这里确定位置。
    if (pending != null) return;
    if (clock.paused) return;

    // 已提交的切图请求先进入过渡，不再瞬时换图。
    if (world.hasIdentity(actor.Player, Transition)) {
        mapFade.phase = .out;
        mapFade.timer.restart();
        return;
    }

    system.update(&world, delta);
    map.update(&world);
}

fn updateMapFade(delta: f32) bool {
    const phase = mapFade.phase orelse return false;
    if (mapFade.timer.updateRunning(delta)) return true;

    switch (phase) {
        .out => {
            const clock = world.getPtr(world.entity, resource.Clock).?;
            const playerEntity = world.getIdentity(actor.Player).?;
            const request = world.get(playerEntity, Transition).?;
            map.exit(&world, clock.day);
            const keep = .{
                resource.Clock,
                resource.Inventory,
                resource.Notice,
                resource.Speed,
            };
            world.resetKeep(keep);
            world.entity = world.createEntity();
            map.enter(
                &world,
                request.target,
                request.targetId,
                clock.day,
            );
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
            const clock = world.getPtr(world.entity, resource.Clock).?;
            mapFade = .{};
            map.exit(&world, clock.day);
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
    const clock = world.getPtr(world.entity, resource.Clock).?;

    zhu.camera.main.scale = .square(2);
    if (loadSlot == null) {
        // 新游戏重置世界级状态；读档会在基础地图创建后覆盖状态。
        clock.reset();
        world.getPtr(world.entity, resource.Notice).?.reset();
        map.resetState();
    }

    const keep = .{
        resource.Clock,
        resource.Inventory,
        resource.Notice,
        resource.Speed,
    };
    world.resetKeep(keep);
    world.entity = world.createEntity();
    map.enter(&world, .exterior, -1, clock.day);
    const inv = world.getPtr(world.entity, resource.Inventory).?;
    inv.reset();
    ui.resetInventory();
    if (loadSlot == null) {
        _ = inv.add(.hoe, 1);
        _ = inv.add(.water, 1);
        _ = inv.add(.pickaxe, 1);
        _ = inv.add(.axe, 1);
        _ = inv.add(.sickle, 1);
    }

    if (loadSlot) |slot| {
        // 存档恢复依赖已经存在的 world/map/player 基础结构。
        if (!loadPlay(slot)) {
            pending = .title;
            return;
        }
    }
    zhu.audio.playMusic("audio/01_spring_journey.ogg");
}

fn savePlay(slot: u8) bool {
    const clock = world.getPtr(world.entity, resource.Clock).?;

    map.saveState(&world, clock.day);
    const record = captureRecord(clock) catch |err| {
        std.log.err("capture save slot {} failed: {}", .{ slot, err });
        return false;
    };
    defer freeRecord(record);

    storage.write(slot, record) catch |err| {
        std.log.err("save slot {} failed: {}", .{ slot, err });
        return false;
    };
    return true;
}

fn loadPlay(slot: u8) bool {
    var record = storage.read(slot) catch |err| {
        std.log.err("load slot {} failed: {}", .{ slot, err });
        return false;
    };
    defer record.deinit();

    restoreRecord(record.value) catch |err| {
        std.log.err("restore slot {} failed: {}", .{ slot, err });
        return false;
    };
    return true;
}

fn captureRecord(
    clock: *const resource.Clock,
) !storage.Record {
    const inv = world.getPtr(world.entity, resource.Inventory).?;

    return .{
        .timestamp = zhu.window.timestamp().toSeconds(),
        .time = clock.*,
        .player = player.capture(&world, map.current),
        .inventory = inv.capture(),
        .maps = try map.captureState(allocator.raw),
    };
}

fn freeRecord(record: storage.Record) void {
    map.freeCapture(allocator.raw, record.maps);
}

fn restoreRecord(record: storage.Record) !void {
    const clock = world.getPtr(world.entity, resource.Clock).?;

    clock.* = record.time;

    map.exit(&world, clock.day);
    try map.restoreSaved(record.maps, clock.day);

    const keep = .{
        resource.Clock,
        resource.Inventory,
        resource.Notice,
        resource.Speed,
    };
    world.resetKeep(keep);
    world.entity = world.createEntity();
    map.enter(&world, record.player.map, -1, clock.day);
    player.restore(&world, record.player);
    ui.resetInventory();
    world.getPtr(world.entity, resource.Inventory).?.restore(record.inventory);
}

fn drawPlay() void {
    map.drawBack();
    system.render.draw(&world);
    map.drawFront();

    system.control.draw(&world);
    system.dialog.draw(&world);
    system.light.draw(&world);

    zhu.camera.push(.window);
    defer zhu.camera.pop();
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
