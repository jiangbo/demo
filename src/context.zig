const std = @import("std");
const ecs = @import("ecs");

pub const Context = struct {
    allocator: std.mem.Allocator,
    registry: *ecs.Registry,
    config: Config = Config{},

    pub fn init(allocator: std.mem.Allocator, reg: *ecs.Registry) Context {
        return Context{ .allocator = allocator, .registry = reg };
    }
    pub fn deinit(self: *Context) void {
        self.registry.deinit();
    }
};

pub const Config = struct {
    tileSize: usize = 32,
    width: usize = 40 * 32,
    height: usize = 25 * 32,
    title: [:0]const u8 = "Dungeon crawl",
};
