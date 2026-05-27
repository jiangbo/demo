const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");

const event = component.event;
const light = component.light;
const Position = component.Position;

const Keyframe = struct {
    hour: f32,
    color: zhu.Color,
};

// 屏幕覆盖色关键帧：只做可见昼夜色调，不模拟真实光照。
const keyframes = [_]Keyframe{
    .{ .hour = 4, .color = .rgba(0.04, 0.06, 0.16, 0.42) },
    .{ .hour = 6, .color = .rgba(0.68, 0.30, 0.10, 0.18) },
    .{ .hour = 9, .color = .rgba(0, 0, 0, 0) },
    .{ .hour = 14, .color = .rgba(0, 0, 0, 0) },
    .{ .hour = 18, .color = .rgba(0.80, 0.32, 0.08, 0.22) },
    .{ .hour = 22, .color = .rgba(0.03, 0.05, 0.18, 0.48) },
    .{ .hour = 28, .color = .rgba(0.04, 0.06, 0.16, 0.42) },
};

var glowImage: zhu.Image = undefined;

pub fn init() void {
    glowImage = zhu.assets.loadImage("assets/light.png");
    glowImage.size = .xy(128, 128);
}

pub fn update(world: *zhu.ecs.World) void {
    // 手动灯光切换（按 L 键）
    const toggle = !context.ui.wantCapture() and zhu.input.key.pressed(.L);
    const dark = context.time.isDark();
    var manuals = world.query(.{light.Manual});
    while (manuals.next()) |entity| {
        const manual = manuals.getPtr(entity, light.Manual);
        if (toggle) manual.wantedOn = !manual.wantedOn;
        setDisabled(world, entity, !(dark and manual.wantedOn));
    }

    // 整点事件时切换昼夜灯光
    if (world.getEvent(event.HourChanged).items.len == 0) return;

    var nightQuery = world.query(.{light.NightOnly});
    while (nightQuery.next()) |entity| setDisabled(world, entity, !dark);

    var dayQuery = world.query(.{light.DayOnly});
    while (dayQuery.next()) |entity| setDisabled(world, entity, dark);
}

pub fn draw() void {
    drawOverlay();
}

pub fn drawOverlay() void {
    const hour = @as(f32, @floatFromInt(context.time.hour)) +
        context.time.minute / 60;
    const overlay = overlayAt(hour);
    if (overlay.a <= 0.001) return;

    zhu.batch.drawRect(.init(.zero, zhu.camera.size), .{
        .color = overlay,
    });
}

pub fn drawWorld(world: *zhu.ecs.World) void {
    const allPoint = .{ Position, light.Point };
    var points = world.queryNone(allPoint, .{light.Disabled});
    while (points.next()) |entity| {
        const pos = points.get(entity, Position);
        const point = points.get(entity, light.Point);
        const center = pos.add(point.offset);
        const alpha = std.math.clamp(point.intensity, 0, 1);
        const color = zhu.Color.rgba(
            point.color.r,
            point.color.g,
            point.color.b,
            0.68 * alpha,
        );
        drawGlow(center, point.radius * 2.0, color);
    }

    const allSpot = .{ Position, light.Spot };
    // 第一版不做真实锥形，先退化成圆形占位光圈验证地图数据。
    var spots = world.queryNone(allSpot, .{light.Disabled});
    while (spots.next()) |entity| {
        const pos = spots.get(entity, Position);
        const spot = spots.get(entity, light.Spot);
        const alpha = std.math.clamp(spot.intensity, 0, 1);
        const color = zhu.Color.rgba(
            spot.color.r,
            spot.color.g,
            spot.color.b,
            0.56 * alpha,
        );
        drawGlow(pos, spot.radius * 1.6, color);
    }
}

pub fn overlayAt(hour: f32) zhu.Color {
    const sampleHour = if (hour < 4) hour + 24 else hour;

    var i: usize = 0;
    while (i + 1 < keyframes.len) : (i += 1) {
        const left = keyframes[i];
        const right = keyframes[i + 1];
        if (sampleHour >= left.hour and sampleHour < right.hour) {
            const t = smoothStep((sampleHour - left.hour) /
                (right.hour - left.hour));
            return left.color.mix(right.color, t);
        }
    }

    return keyframes[keyframes.len - 1].color;
}

fn setDisabled(world: *zhu.ecs.World, entity: zhu.ecs.Entity, disabled: bool) void {
    if (disabled) {
        world.add(entity, light.Disabled{});
    } else {
        world.remove(entity, light.Disabled);
    }
}

fn drawGlow(center: zhu.Vector2, size: f32, color: zhu.Color) void {
    zhu.batch.drawImage(glowImage, center.add(.xy(-size * 0.5, -size * 0.5)), .{
        .size = .square(size),
        .color = color,
    });
}

fn smoothStep(value: f32) f32 {
    const t = std.math.clamp(value, 0, 1);
    return t * t * (3 - 2 * t);
}

test "light overlay 正午不改变画面" {
    const color = overlayAt(12);
    try std.testing.expectApproxEqAbs(@as(f32, 0), color.a, 0.001);
}

test "light overlay 深夜比白天更明显" {
    const night = overlayAt(23);
    const noon = overlayAt(12);

    try std.testing.expect(night.a > noon.a);
    try std.testing.expect(night.b > night.r);
}

test "light overlay 黄昏偏暖" {
    const color = overlayAt(18);

    try std.testing.expect(color.a > 0.1);
    try std.testing.expect(color.r > color.b);
}

test "light overlay 黎明偏暖" {
    const color = overlayAt(6);

    try std.testing.expect(color.a > 0.1);
    try std.testing.expect(color.r > color.b);
}

test "light overlay 支持跨午夜插值" {
    const night = overlayAt(22);
    const middle = overlayAt(1);
    const early = overlayAt(4);

    try std.testing.expect(night.a > middle.a);
    try std.testing.expect(middle.a > early.a);
}

test "light update 没有整点事件时不切换显隐" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, light.NightOnly{});
    context.time.hour = 19;
    context.time.minute = 0;

    update(&world);

    try std.testing.expect(!world.has(entity, light.Disabled));
}

test "light update 夜晚启用 night-only 并禁用 day-only" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const night = world.createEntity();
    world.add(night, light.NightOnly{});
    world.add(night, light.Disabled{});

    const day = world.createEntity();
    world.add(day, light.DayOnly{});

    context.time.hour = 19;
    context.time.minute = 0;
    world.addEvent(event.HourChanged{ .day = 1, .hour = 19 });

    update(&world);

    try std.testing.expect(!world.has(night, light.Disabled));
    try std.testing.expect(world.has(day, light.Disabled));
}

test "light update 白天禁用 night-only 并启用 day-only" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const night = world.createEntity();
    world.add(night, light.NightOnly{});

    const day = world.createEntity();
    world.add(day, light.DayOnly{});
    world.add(day, light.Disabled{});

    context.time.hour = 12;
    context.time.minute = 0;
    world.addEvent(event.HourChanged{ .day = 1, .hour = 12 });

    update(&world);

    try std.testing.expect(world.has(night, light.Disabled));
    try std.testing.expect(!world.has(day, light.Disabled));
}

test "light drawWorld 只绘制启用点光" {
    glowImage = .{ .texture = .{ .id = 1 }, .size = .xy(128, 128) };

    var vertices: [8]zhu.batch.Vertex = undefined;
    var commands: [4]zhu.batch.Command = undefined;
    zhu.batch.vertexBuffer = .initBuffer(&vertices);
    zhu.batch.commandBuffer = .initBuffer(&commands);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const visible = world.createEntity();
    world.add(visible, Position.xy(10, 20));
    world.add(visible, light.Point{ .radius = 16 });

    const disabled = world.createEntity();
    world.add(disabled, Position.xy(30, 40));
    world.add(disabled, light.Point{ .radius = 16 });
    world.add(disabled, light.Disabled{});

    drawWorld(&world);

    try std.testing.expectEqual(@as(usize, 1), zhu.batch.vertexBuffer.items.len);
}

test "light drawWorld 会把 spot 退化成占位光圈" {
    glowImage = .{ .texture = .{ .id = 1 }, .size = .xy(128, 128) };

    var vertices: [8]zhu.batch.Vertex = undefined;
    var commands: [4]zhu.batch.Command = undefined;
    zhu.batch.vertexBuffer = .initBuffer(&vertices);
    zhu.batch.commandBuffer = .initBuffer(&commands);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, Position.xy(10, 20));
    world.add(entity, light.Spot{ .radius = 16 });

    drawWorld(&world);

    try std.testing.expectEqual(@as(usize, 1), zhu.batch.vertexBuffer.items.len);
}

fn resetInput() void {
    zhu.input.key.state = .initEmpty();
    zhu.input.key.lastState = .initEmpty();
    context.ui.wantCaptureKeyboard = false;
}

fn pressKey(keyCode: zhu.input.KeyCode) void {
    zhu.input.key.state.set(@intCast(@intFromEnum(keyCode)));
}

test "manual light 白天保持禁用" {
    resetInput();
    defer resetInput();
    context.time.hour = 12;
    context.time.minute = 0;
    pressKey(.L);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, light.Manual{});

    update(&world);

    try std.testing.expect(world.has(entity, light.Disabled));
    try std.testing.expect(world.get(entity, light.Manual).?.wantedOn);
}

test "manual light 夜晚按键切换启用和禁用" {
    resetInput();
    defer resetInput();
    context.time.hour = 19;
    context.time.minute = 0;
    pressKey(.L);

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    world.add(entity, light.Manual{});
    world.add(entity, light.Disabled{});

    update(&world);

    try std.testing.expect(!world.has(entity, light.Disabled));
    try std.testing.expect(world.get(entity, light.Manual).?.wantedOn);

    zhu.input.key.lastState = zhu.input.key.state;
    update(&world);

    try std.testing.expect(!world.has(entity, light.Disabled));

    zhu.input.key.lastState = .initEmpty();
    update(&world);

    try std.testing.expect(world.has(entity, light.Disabled));
    try std.testing.expect(!world.get(entity, light.Manual).?.wantedOn);
}
