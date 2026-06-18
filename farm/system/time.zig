const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");

const event = component.event;
const clock = context.clock;

const uiScale: f32 = 2.0;
const clockSize = zhu.Vector2.xy(32, 32);

var extras: zhu.Image = undefined;
var clockFace: zhu.Image = undefined;
var clockHand: zhu.Image = undefined;
var panelImage: zhu.NineImage = undefined;
var labelImage: zhu.NineImage = undefined;

pub fn init() void {
    extras = zhu.getImage("farm-rpg/UI/Clock/Extras.png").?;
    clockFace = zhu.getImage("farm-rpg/UI/Clock/Clock.png").?
        .sub(.init(.zero, clockSize));
    clockHand = zhu.getImage("farm-rpg/UI/Clock/clock hand.png").?;

    var image = extras.sub(.init(.xy(66, 65), .xy(59, 28)));
    panelImage = .{
        .image = image,
        .patch = .{ .min = .xy(1, 3), .max = .xy(1, 1) },
    };

    image = extras.sub(.init(.xy(71, 99), .xy(33, 10)));
    labelImage = .{
        .image = image,
        .patch = .{ .min = .xy(1, 1), .max = .xy(1, 1) },
    };
}

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    world.clearEvent(event.HourChanged);
    world.clearEvent(event.DayChanged);
    world.clearEvent(event.PeriodChanged);

    if (clock.takeRestHours()) |hours| {
        clock.minute = 0;
        for (0..hours) |_| advanceOneHour(world);
        return;
    }

    clock.minute += delta * clock.minutesPerRealSecond;
    while (clock.minute >= 60.0) {
        clock.minute -= 60.0;
        advanceOneHour(world);
    }
}

fn advanceOneHour(world: *zhu.ecs.World) void {
    clock.hour += 1;

    if (clock.hour >= 24) {
        clock.hour = 0;
        clock.day += 1;
        world.addEvent(event.DayChanged{ .day = clock.day });
    }

    world.addEvent(event.HourChanged{
        .day = clock.day,
        .hour = clock.hour,
    });

    updatePeriod(world);
}

fn updatePeriod(world: *zhu.ecs.World) void {
    const nextPeriod = currentPeriod(clock.hour);
    if (nextPeriod != clock.period) {
        clock.period = nextPeriod;
        world.addEvent(event.PeriodChanged{
            .day = clock.day,
            .hour = clock.hour,
            .period = nextPeriod,
        });
    }
}

pub fn draw() void {
    zhu.camera.push(.windowScale(.xy(10, 10), .square(uiScale)));
    defer zhu.camera.pop();

    zhu.batch.drawNine(panelImage, panelImage.rectAt(.xy(20, 0)));
    zhu.batch.drawImage(clockFace, .xy(0, -2), .{});

    const index: u8 = ((clock.hour + 13) % 24) / 3;
    const handX = @as(f32, @floatFromInt(index)) * clockSize.x;
    const image = clockHand.sub(.init(.xy(handX, 0), clockSize));
    zhu.batch.drawImage(image, .xy(0, -2), .{});

    const size = labelImage.image.size;
    const rect = zhu.Rect.init(.xy(34, 3), size);
    const timeRect = rect.move(.xy(0, size.y + 2));
    zhu.batch.drawNine(labelImage, rect);
    zhu.batch.drawNine(labelImage, timeRect);

    var buffer: [16]u8 = undefined;
    var option: zhu.text.Option = .{
        .scale = .square(1.0 / uiScale),
        .anchor = .center,
    };
    const dayText = zhu.format(&buffer, "Day {d}", .{clock.day});
    zhu.text.draw(dayText, rect.center(), option);

    const args = .{ clock.hour, @as(u8, @intFromFloat(clock.minute)) };
    const timeText = zhu.format(&buffer, "{d:0>2}:{d:0>2}", args);
    option.offset = .xy(0, 1 / uiScale);
    zhu.text.draw(timeText, timeRect.center(), option);
}

fn currentPeriod(hour: u8) component.time.Period {
    return switch (hour) {
        4...7 => .dawn,
        8...15 => .day,
        16...19 => .dusk,
        else => .night,
    };
}

test "时间推进到整点会发出小时事件" {
    context.init();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    clock.hour = 6;
    clock.minute = 59.0;
    update(&world, 0.2);

    try std.testing.expectEqual(7, clock.hour);
    try std.testing.expectEqual(1.0, clock.minute);

    const hours = world.getEvent(event.HourChanged);
    try std.testing.expectEqual(1, hours.len);
    try std.testing.expectEqual(1, hours[0].day);
    try std.testing.expectEqual(7, hours[0].hour);
}

test "时间推进跨天会发出新一天事件" {
    context.init();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    clock.hour = 23;
    clock.minute = 59.0;
    clock.period = .night;
    update(&world, 0.2);

    try std.testing.expectEqual(2, clock.day);
    try std.testing.expectEqual(0, clock.hour);
    try std.testing.expectEqual(1.0, clock.minute);

    const days = world.getEvent(event.DayChanged);
    try std.testing.expectEqual(1, days.len);
    try std.testing.expectEqual(2, days[0].day);

    const hours = world.getEvent(event.HourChanged);
    try std.testing.expectEqual(1, hours.len);
    try std.testing.expectEqual(2, hours[0].day);
    try std.testing.expectEqual(0, hours[0].hour);
}

test "按小时推进会清零分钟并逐小时发事件" {
    context.init();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    clock.hour = 22;
    clock.minute = 37.0;
    clock.period = .night;
    clock.restHours = 3;
    update(&world, 0);

    try std.testing.expectEqual(2, clock.day);
    try std.testing.expectEqual(1, clock.hour);
    try std.testing.expectEqual(@as(f32, 0), clock.minute);
    try std.testing.expectEqual(null, clock.restHours);

    const days = world.getEvent(event.DayChanged);
    try std.testing.expectEqual(1, days.len);
    try std.testing.expectEqual(2, days[0].day);

    const hours = world.getEvent(event.HourChanged);
    try std.testing.expectEqual(3, hours.len);
    try std.testing.expectEqual(23, hours[0].hour);
    try std.testing.expectEqual(0, hours[1].hour);
    try std.testing.expectEqual(1, hours[2].hour);
}

test "时段跨过边界会发出时段事件" {
    context.init();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    clock.hour = 7;
    clock.minute = 59.0;
    clock.period = .dawn;
    update(&world, 0.2);

    try std.testing.expectEqual(currentPeriod(8), clock.period);

    const periods = world.getEvent(event.PeriodChanged);
    try std.testing.expectEqual(1, periods.len);
    try std.testing.expectEqual(currentPeriod(8), periods[0].period);
}
