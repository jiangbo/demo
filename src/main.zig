const std = @import("std");
const ecs = @import("ecs.zig");

const Health = struct { health: u32, maxHealth: u32 };

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();

    var registry = ecs.Registry.init(gpa.allocator());
    defer registry.deinit();

    const e1 = registry.create();
    std.log.info("e1: {}", .{e1});
    registry.add(e1, Health{ .health = 1, .maxHealth = 1 });
    std.log.info("e1 health: {?}", .{registry.get(e1, Health)});

    const e2 = registry.create();
    std.log.info("e2: {}", .{e2});
    registry.add(e2, Health{ .health = 2, .maxHealth = 2 });
    std.log.info("e2 health: {?}", .{registry.get(e2, Health)});

    std.log.info("e2 has health: {}", .{registry.has(e2, Health)});

    registry.remove(e2, Health);
    std.log.info("e2 health: {}", .{registry.has(e2, Health)});
}
