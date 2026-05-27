const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");

const event = component.event;
const sound = component.sound;

pub fn update(world: *zhu.ecs.World) void {
    const sounds = world.getEvent(event.SoundPlay);
    for (sounds.items) |evt| zhu.audio.playSound(path(evt.id));
    sounds.clearRetainingCapacity();
}

fn path(id: sound.Id) [:0]const u8 {
    return switch (id) {
        .hoe => "assets/audio/shovel-stab.ogg",
        .water => "assets/audio/water_splash.ogg",
        .harvest => "assets/audio/plant_harvest.ogg",
        .pickup => "assets/audio/pop.ogg",
        .plant => "assets/audio/planting-sounds.ogg",
    };
}

test "sound id 映射到音频文件" {
    try std.testing.expectEqualStrings(
        "assets/audio/shovel-stab.ogg",
        path(.hoe),
    );
    try std.testing.expectEqualStrings(
        "assets/audio/water_splash.ogg",
        path(.water),
    );
    try std.testing.expectEqualStrings(
        "assets/audio/pop.ogg",
        path(.pickup),
    );
}

test "sound update 消费播放事件" {
    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    world.addEvent(event.SoundPlay{ .id = .hoe });
    world.addEvent(event.SoundPlay{ .id = .pickup });

    update(&world);

    const sounds = world.getEvent(event.SoundPlay).items;
    try std.testing.expectEqual(0, sounds.len);
}
