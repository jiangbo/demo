const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const context = @import("../context.zig");

const event = component.event;

// 游戏内时间流速：真实 1 秒对应多少游戏分钟
const minutesPerRealSecond: f32 = 10.0;
const uiScale: f32 = 2.0;

var extras: zhu.Image = undefined;
var clockFace: zhu.Image = undefined;
var clockHand: zhu.Image = undefined;

pub fn init() void {
    extras = zhu.getImage("farm-rpg/UI/Clock/Extras.png").?;
    clockFace = zhu.getImage("farm-rpg/UI/Clock/Clock.png").?;
    clockHand = zhu.getImage("farm-rpg/UI/Clock/clock hand.png").?;
}

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    world.clearEvent(event.HourChanged);
    world.clearEvent(event.DayChanged);
    world.clearEvent(event.PeriodChanged);

    context.time.minute += delta * minutesPerRealSecond;
    while (context.time.minute >= 60.0) {
        context.time.minute -= 60.0;
        context.time.hour += 1;

        if (context.time.hour >= 24) {
            context.time.hour = 0;
            context.time.day += 1;
            world.addEvent(event.DayChanged{ .day = context.time.day });
        }

        world.addEvent(event.HourChanged{
            .day = context.time.day,
            .hour = context.time.hour,
        });
    }

    const nextPeriod = currentPeriod(context.time.hour);
    if (nextPeriod != context.time.period) {
        context.time.period = nextPeriod;
        world.addEvent(event.PeriodChanged{
            .day = context.time.day,
            .hour = context.time.hour,
            .period = nextPeriod,
        });
    }
}

pub fn draw() void {
    const pos = zhu.Vector2.xy(10, 10);
    const clockSourceSize = zhu.Vector2.xy(32, 32);
    const panelSourceSize = zhu.Vector2.xy(59, 28);
    const labelSize = zhu.Vector2.xy(33, 10).scale(uiScale);

    const clockSize = clockSourceSize.scale(uiScale);
    const panelSize = panelSourceSize.scale(uiScale);

    var image = extras.sub(.init(.xy(66, 65), panelSourceSize));
    zhu.batch.drawNine(image, .init(pos.addX(20 * uiScale), panelSize), .{
        .topLeft = .xy(1, 3),
        .bottomRight = .xy(1, 1),
    });

    image = clockFace.sub(.init(.zero, clockSourceSize));
    zhu.batch.drawImage(image, pos.addY(-2 * uiScale), .{
        .size = clockSize,
    });

    const index: u8 = ((context.time.hour + 13) % 24) / 3;
    const handX = @as(f32, @floatFromInt(index)) * clockSourceSize.x;
    image = clockHand.sub(.init(.xy(handX, 0), clockSourceSize));
    zhu.batch.drawImage(image, pos.addY(-2 * uiScale), .{
        .size = clockSize,
    });

    var buffer: [16]u8 = undefined;
    const day = zhu.format(&buffer, "Day {d}", .{context.time.day});
    var labelPos = pos.add(zhu.Vector2.xy(34, 3).scale(uiScale));
    drawLabel(.init(labelPos, labelSize), day);
    labelPos = labelPos.addY(labelSize.y + 2 * uiScale);
    const clock = zhu.format(&buffer, "{d:0>2}:{d:0>2}", .{
        context.time.hour,
        @as(u8, @intFromFloat(context.time.minute)),
    });
    drawLabel(.init(labelPos, labelSize), clock);
}

fn currentPeriod(hour: u8) component.time.Period {
    return switch (hour) {
        4...7 => .dawn,
        8...15 => .day,
        16...19 => .dusk,
        else => .night,
    };
}

fn drawLabel(rect: zhu.Rect, text: []const u8) void {
    const labelSourceSize = zhu.Vector2.xy(33, 10);
    const labelImage = extras.sub(.init(.xy(71, 99), labelSourceSize));
    zhu.batch.drawNine(labelImage, rect, .{
        .topLeft = .xy(1, 1),
        .bottomRight = .xy(1, 1),
    });

    const width = zhu.text.measure(text, .{}).x;
    const textPos = rect.min.add(.xy(
        @max(0.0, (rect.size.x - width) / 2),
        2,
    ));
    zhu.text.drawString(text, textPos, .{});
}

test "时间推进到整点会发出小时事件" {
    context.init();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    context.time.hour = 6;
    context.time.minute = 59.0;
    update(&world, 0.2);

    try std.testing.expectEqual(7, context.time.hour);
    try std.testing.expectEqual(1.0, context.time.minute);

    const hours = world.getEvent(event.HourChanged).items;
    try std.testing.expectEqual(1, hours.len);
    try std.testing.expectEqual(1, hours[0].day);
    try std.testing.expectEqual(7, hours[0].hour);
}

test "时间推进跨天会发出新一天事件" {
    context.init();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    context.time.hour = 23;
    context.time.minute = 59.0;
    context.time.period = .night;
    update(&world, 0.2);

    try std.testing.expectEqual(2, context.time.day);
    try std.testing.expectEqual(0, context.time.hour);
    try std.testing.expectEqual(1.0, context.time.minute);

    const days = world.getEvent(event.DayChanged).items;
    try std.testing.expectEqual(1, days.len);
    try std.testing.expectEqual(2, days[0].day);

    const hours = world.getEvent(event.HourChanged).items;
    try std.testing.expectEqual(1, hours.len);
    try std.testing.expectEqual(2, hours[0].day);
    try std.testing.expectEqual(0, hours[0].hour);
}

test "时段跨过边界会发出时段事件" {
    context.init();

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    context.time.hour = 7;
    context.time.minute = 59.0;
    context.time.period = .dawn;
    update(&world, 0.2);

    try std.testing.expectEqual(currentPeriod(8), context.time.period);

    const periods = world.getEvent(event.PeriodChanged).items;
    try std.testing.expectEqual(1, periods.len);
    try std.testing.expectEqual(currentPeriod(8), periods[0].period);
}

test "时段判断按整点小时分段" {
    try std.testing.expectEqual(currentPeriod(21), .night);
    try std.testing.expectEqual(currentPeriod(3), .night);
    try std.testing.expectEqual(currentPeriod(5), .dawn);
}

test "时间文本不会提前进位到下一分钟" {
    var buffer: [16]u8 = undefined;
    const clock = zhu.format(&buffer, "{d:0>2}:{d:0>2}", .{
        23,
        @as(u8, @intFromFloat(59.9)),
    });

    try std.testing.expectEqualStrings("23:59", clock);
}
