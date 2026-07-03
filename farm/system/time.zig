const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const Clock = @import("../global/Clock.zig");

const event = component.event;

pub fn update(world: *zhu.ecs.World, speed: f32, delta: f32) void {
    const clock = world.getPtr(world.entity, Clock).?;

    world.clearEvent(event.HourChanged);
    world.clearEvent(event.DayChanged);
    world.clearEvent(event.PeriodChanged);

    if (clock.takeRestHours()) |hours| {
        clock.minute = 0;
        for (0..hours) |_| advanceOneHour(world, clock);
        return;
    }

    clock.minute += delta * speed * 10.0;
    while (clock.minute >= 60.0) {
        clock.minute -= 60.0;
        advanceOneHour(world, clock);
    }
}

fn advanceOneHour(world: *zhu.ecs.World, clock: *Clock) void {
    clock.hour += 1;

    if (clock.hour >= 24) {
        clock.hour = 0;
        clock.day += 1;
        world.addEvent(event.DayChanged{ .day = clock.day });
    }

    world.addEvent(event.HourChanged{});

    updatePeriod(world, clock);
}

fn updatePeriod(world: *zhu.ecs.World, clock: *Clock) void {
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

fn currentPeriod(hour: u8) component.time.Period {
    return switch (hour) {
        4...7 => .dawn,
        8...15 => .day,
        16...19 => .dusk,
        else => .night,
    };
}

test "时间推进到整点会发出小时事件" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    world.add(world.entity, Clock{});
    const clock = world.getPtr(world.entity, Clock).?;
    clock.hour = 6;
    clock.minute = 59.0;
    update(&world, 1, 0.2);

    try std.testing.expectEqual(7, clock.hour);
    try std.testing.expectEqual(1.0, clock.minute);

    const hours = world.getEvent(event.HourChanged);
    try std.testing.expectEqual(1, hours.len);
}

test "时间推进跨天会发出新一天事件" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    world.add(world.entity, Clock{});
    const clock = world.getPtr(world.entity, Clock).?;
    clock.hour = 23;
    clock.minute = 59.0;
    clock.period = .night;
    update(&world, 1, 0.2);

    try std.testing.expectEqual(2, clock.day);
    try std.testing.expectEqual(0, clock.hour);
    try std.testing.expectEqual(1.0, clock.minute);

    const days = world.getEvent(event.DayChanged);
    try std.testing.expectEqual(1, days.len);
    try std.testing.expectEqual(2, days[0].day);

    const hours = world.getEvent(event.HourChanged);
    try std.testing.expectEqual(1, hours.len);
}

test "按小时推进会清零分钟并逐小时发事件" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    world.add(world.entity, Clock{});
    const clock = world.getPtr(world.entity, Clock).?;
    clock.hour = 22;
    clock.minute = 37.0;
    clock.period = .night;
    clock.restHours = 3;
    update(&world, 1, 0);

    try std.testing.expectEqual(2, clock.day);
    try std.testing.expectEqual(1, clock.hour);
    try std.testing.expectEqual(@as(f32, 0), clock.minute);
    try std.testing.expectEqual(null, clock.restHours);

    const days = world.getEvent(event.DayChanged);
    try std.testing.expectEqual(1, days.len);
    try std.testing.expectEqual(2, days[0].day);

    const hours = world.getEvent(event.HourChanged);
    try std.testing.expectEqual(3, hours.len);
}

test "时段跨过边界会发出时段事件" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.entity = world.createEntity();
    world.add(world.entity, Clock{});
    const clock = world.getPtr(world.entity, Clock).?;
    clock.hour = 7;
    clock.minute = 59.0;
    clock.period = .dawn;
    update(&world, 1, 0.2);

    try std.testing.expectEqual(currentPeriod(8), clock.period);

    const periods = world.getEvent(event.PeriodChanged);
    try std.testing.expectEqual(1, periods.len);
    try std.testing.expectEqual(currentPeriod(8), periods[0].period);
}
