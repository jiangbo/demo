const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");

var extras: zhu.Image = undefined;
var clockFace: zhu.Image = undefined;
var clockHand: zhu.Image = undefined;

pub fn init() void {
    extras = zhu.getImage("farm-rpg/UI/Clock/Extras.png").?;
    clockFace = zhu.getImage("farm-rpg/UI/Clock/Clock.png").?;
    clockHand = zhu.getImage("farm-rpg/UI/Clock/clock hand.png").?;
}

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    clearEvents(world);

    context.time.minute += delta * context.time.minutesPerRealSecond;

    while (context.time.minute >= 60.0) {
        context.time.minute -= 60.0;
        context.time.hour += 1.0;

        if (context.time.hour >= 24.0) {
            context.time.hour -= 24.0;
            context.time.day += 1;
            world.addEvent(component.event.DayChanged{ .day = context.time.day });
        }

        world.addEvent(component.event.HourChanged{
            .day = context.time.day,
            .hour = currentHour(),
        });
    }

    const nextPeriod = context.time.calculatePeriod(context.time.hourWithMinute());
    if (nextPeriod != context.time.period) {
        context.time.period = nextPeriod;
        world.addEvent(component.event.PeriodChanged{
            .day = context.time.day,
            .hour = currentHour(),
            .period = nextPeriod,
        });
    }
}

pub fn draw() void {
    const pos = zhu.Vector2.xy(6, 6);
    const clockSize = zhu.Vector2.xy(32, 32);
    const panelSize = zhu.Vector2.xy(59, 28);
    const labelSize = zhu.Vector2.xy(33, 10);

    const panelImage = extras.sub(.init(.xy(66, 65), panelSize));
    zhu.batch.drawNine(panelImage, .init(pos.addX(20), panelSize), .{
        .topLeft = .xy(1, 3),
        .bottomRight = .xy(1, 1),
    });

    const clockPos = pos.addY(-2);
    zhu.batch.drawImage(clockFace.sub(.init(.zero, clockSize)), clockPos, .{
        .size = clockSize,
    });

    const handX = @as(f32, @floatFromInt(context.time.handIndex())) *
        clockSize.x;
    const handImage = clockHand.sub(.init(.xy(handX, 0), clockSize));
    zhu.batch.drawImage(handImage, clockPos, .{
        .size = clockSize,
    });

    var dayBuffer: [16]u8 = undefined;
    var clockBuffer: [16]u8 = undefined;
    const labelPos = pos.add(.xy(34, 3));
    drawLabel(.init(labelPos, labelSize), context.time.formatDay(&dayBuffer));
    drawLabel(
        .init(labelPos.addY(labelSize.y + 2), labelSize),
        context.time.formatClock(&clockBuffer),
    );
}

fn currentHour() u8 {
    return @intFromFloat(@floor(context.time.hour));
}

fn clearEvents(world: *zhu.ecs.World) void {
    world.clearEvent(component.event.HourChanged);
    world.clearEvent(component.event.DayChanged);
    world.clearEvent(component.event.PeriodChanged);
}

fn drawLabel(rect: zhu.Rect, text: []const u8) void {
    const labelImage = extras.sub(.init(.xy(71, 99), rect.size));
    zhu.batch.drawNine(labelImage, rect, .{
        .topLeft = .xy(1, 1),
        .bottomRight = .xy(1, 1),
    });

    const width = zhu.text.computeTextWidth(text, .{});
    const textPos = rect.min.add(.xy(@max(0.0, (rect.size.x - width) / 2), 1));
    zhu.text.drawString(text, textPos, .{ .color = .white });
}

test "时间推进到整点会发出小时事件" {
    context.init();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    context.time.hour = 6.0;
    context.time.minute = 59.0;
    update(&world, 0.2);

    try std.testing.expectEqual(@as(f32, 7.0), context.time.hour);
    try std.testing.expectEqual(@as(f32, 1.0), context.time.minute);

    const hours = world.getEvent(component.event.HourChanged).items;
    try std.testing.expectEqual(@as(usize, 1), hours.len);
    try std.testing.expectEqual(@as(u32, 1), hours[0].day);
    try std.testing.expectEqual(@as(u8, 7), hours[0].hour);
}

test "时间推进跨天会发出新一天事件" {
    context.init();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    context.time.hour = 23.0;
    context.time.minute = 59.0;
    context.time.period = .night;
    update(&world, 0.2);

    try std.testing.expectEqual(@as(u32, 2), context.time.day);
    try std.testing.expectEqual(@as(f32, 0.0), context.time.hour);
    try std.testing.expectEqual(@as(f32, 1.0), context.time.minute);

    const days = world.getEvent(component.event.DayChanged).items;
    try std.testing.expectEqual(@as(usize, 1), days.len);
    try std.testing.expectEqual(@as(u32, 2), days[0].day);

    const hours = world.getEvent(component.event.HourChanged).items;
    try std.testing.expectEqual(@as(usize, 1), hours.len);
    try std.testing.expectEqual(@as(u32, 2), hours[0].day);
    try std.testing.expectEqual(@as(u8, 0), hours[0].hour);
}

test "时段跨过边界会发出时段事件" {
    context.init();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    context.time.hour = 7.0;
    context.time.minute = 59.0;
    context.time.period = .dawn;
    update(&world, 0.2);

    try std.testing.expectEqual(context.time.Period.day, context.time.period);

    const periods = world.getEvent(component.event.PeriodChanged).items;
    try std.testing.expectEqual(@as(usize, 1), periods.len);
    try std.testing.expectEqual(context.time.Period.day, periods[0].period);
}

test "夜晚时段支持跨天窗口" {
    try std.testing.expectEqual(
        context.time.Period.night,
        context.time.calculatePeriod(21.0),
    );
    try std.testing.expectEqual(
        context.time.Period.night,
        context.time.calculatePeriod(3.5),
    );
    try std.testing.expectEqual(
        context.time.Period.dawn,
        context.time.calculatePeriod(5.0),
    );
}
