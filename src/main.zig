const std = @import("std");
const ecs = @import("zhu").ecs;

const Health = struct { health: u32, maxHealth: u32 };

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();

    var registry = ecs.Registry.init(gpa.allocator());
    defer registry.deinit();

    _ = registry.createEntity();

    const e1 = registry.createEntity();
    std.log.info("e1: {}", .{e1});
    registry.add(e1, Health{ .health = 1, .maxHealth = 1 });
    std.log.info("e1 health: {}", .{registry.get(e1, Health)});

    const e2 = registry.createEntity();
    std.log.info("e2: {}", .{e2});
    registry.add(e2, Health{ .health = 2, .maxHealth = 2 });
    std.log.info("e2 health: {}", .{registry.get(e2, Health)});

    const e3 = registry.createEntity();
    std.log.info("e3: {}", .{e3});
    registry.add(e3, Health{ .health = 3, .maxHealth = 3 });
    std.log.info("e3 health: {}", .{registry.get(e3, Health)});

    std.log.info("e3 has health: {}", .{registry.has(e3, Health)});

    const e4 = registry.createEntity();
    std.log.info("e4: {}", .{e4});
    registry.add(e4, Health{ .health = 4, .maxHealth = 4 });
    std.log.info("e4 health: {}", .{registry.get(e4, Health)});

    registry.remove(e3, Health);

    registry.destroyEntity(e2);

    std.log.info("e4 health: {?}", .{registry.tryGet(e4, Health)});
    std.log.info("e3 has health: {}", .{registry.has(e3, Health)});
}
