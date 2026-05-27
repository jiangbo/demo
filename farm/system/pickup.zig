const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const toolbar = @import("../toolbar.zig");

const Player = component.actor.Player;
const Position = component.Position;
const Pickup = component.item.Pickup;
const event = component.event;

const collectRadius: f32 = 12;

pub fn update(world: *zhu.ecs.World) void {
    const player = world.getIdentity(Player).?;
    const playerPos = world.get(player, Position).?;

    var query = world.query(.{ Pickup, Position }).reverse();
    while (query.next()) |entity| {
        const pickup = query.get(entity, Pickup);
        const position = query.get(entity, Position);
        const distance2 = position.sub(playerPos).length2();
        if (distance2 > collectRadius * collectRadius) continue;

        toolbar.add(pickup.item, pickup.count);
        world.destroyEntity(entity);
        world.addEvent(event.SoundPlay{ .id = .pickup });
    }
}

test "pickup update 拾取物品会发出 pickup 音效" {
    toolbar.slots = @splat(.{ .type = .hoe, .count = 0 });
    toolbar.slotIndex = 0;

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const player = world.createIdentity(Player);
    world.add(player, Position.xy(0, 0));

    const pickup = world.createEntity();
    world.add(pickup, Pickup{ .item = .crop, .count = 1 });
    world.add(pickup, Position.xy(0, 0));

    update(&world);

    const sounds = world.getEvent(event.SoundPlay).items;
    try std.testing.expectEqual(1, sounds.len);
    try std.testing.expectEqual(.pickup, sounds[0].id);
    try std.testing.expect(!world.has(pickup, Pickup));
}
