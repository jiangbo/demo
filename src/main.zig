const std = @import("std");
const engine = @import("engine.zig");
const world = @import("world.zig");

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var registry = engine.Registry.init(gpa.allocator());
    var context = engine.Context.init(gpa.allocator(), &registry);
    defer context.deinit();

    world.run(&context);
}
