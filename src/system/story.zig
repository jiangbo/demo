const std = @import("std");
const ecs = @import("ecs");

const component = @import("../component.zig");
const factory = @import("../factory.zig");

const Actor = component.actor.Actor;
const Speed = component.Speed;
const Story = component.event.Story;
const Talk = component.dialog.Talk;

pub fn update(world: *ecs.World) void {
    for (world.getEvent(Story)) |story| {
        switch (story) {
            .demonAppeared => |p| demonAppeared(world, p),
        }
    }
    world.clearEvent(Story);
}

// 处理大魔王出现后的城市人物变化。
fn demonAppeared(world: *ecs.World, progress: u8) void {
    var query = world.query(.{ Actor, Talk, Speed });
    while (query.next()) |entity| {
        const actor = query.get(entity, Actor);
        const talk = query.getPtr(entity, Talk);
        const speed = query.getPtr(entity, Speed);
        talk.* = factory.actorTalk(actor.key, progress).?;
        speed.value = factory.actorSpeed(actor.key, progress);
    }
}

test "大魔王出现后更新人物的对话和速度" {
    var world = ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();
    const oldTalk: Talk = &.{
        .{ .actor = null, .content = "旧对话" },
    };
    world.addAll(entity, .{
        Actor{ .key = .daYou },
        oldTalk,
        Speed{ .value = 14 },
    });
    world.addEvent(Story{ .demonAppeared = 5 });

    update(&world);

    const talk = world.get(entity, Talk).?;
    const speed = world.get(entity, Speed).?;
    try std.testing.expect(talk.ptr != oldTalk.ptr);
    try std.testing.expect(speed.value != 14);
}
