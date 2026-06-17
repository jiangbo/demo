const std = @import("std");
const zhu = @import("zhu");

test "zero-size event can append and clear" {
    const EmptyEvent = struct {};

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    try std.testing.expectEqual(@as(usize, 0), world.getEvent(EmptyEvent).len);

    world.addEvent(EmptyEvent{});
    world.addEvent(EmptyEvent{});

    try std.testing.expectEqual(@as(usize, 2), world.getEvent(EmptyEvent).len);

    world.clearEvent(EmptyEvent);
    try std.testing.expectEqual(@as(usize, 0), world.getEvent(EmptyEvent).len);
}

test "zero-size component can add twice" {
    const EmptyComponent = struct {};

    var world = zhu.ecs.World.init(std.testing.allocator);
    defer world.deinit();

    const entity = world.createEntity();

    world.add(entity, EmptyComponent{});
    world.add(entity, EmptyComponent{});

    try std.testing.expect(world.has(entity, EmptyComponent));
    try std.testing.expect(world.get(entity, EmptyComponent) != null);
    try std.testing.expectEqual(@as(usize, 1), world.values(EmptyComponent).len);
}

test {
    std.testing.refAllDeclsRecursive(@import("context.zig"));
    std.testing.refAllDeclsRecursive(@import("inventory.zig"));
    std.testing.refAllDeclsRecursive(@import("map.zig"));
    std.testing.refAllDeclsRecursive(@import("factory.zig"));
    std.testing.refAllDeclsRecursive(@import("interact.zig"));
    std.testing.refAllDeclsRecursive(@import("save.zig"));
    std.testing.refAllDeclsRecursive(@import("ui.zig"));
    std.testing.refAllDeclsRecursive(@import("ui/save_slot.zig"));
    std.testing.refAllDeclsRecursive(@import("system/animation.zig"));
    std.testing.refAllDeclsRecursive(@import("system/control.zig"));
    std.testing.refAllDeclsRecursive(@import("system/light.zig"));
    std.testing.refAllDeclsRecursive(@import("system/movement.zig"));
    std.testing.refAllDeclsRecursive(@import("system/pickup.zig"));
    std.testing.refAllDeclsRecursive(@import("system/render.zig"));
    std.testing.refAllDeclsRecursive(@import("system/sound.zig"));
    std.testing.refAllDeclsRecursive(@import("system/time.zig"));
    std.testing.refAllDeclsRecursive(@import("system/transition.zig"));
    std.testing.refAllDeclsRecursive(@import("system/wander.zig"));
}
