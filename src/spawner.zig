const std = @import("std");
const ecs = @import("ecs");

pub fn spawn(registry: ecs.Registry) void {
    std.log.info("", .{registry});
}
