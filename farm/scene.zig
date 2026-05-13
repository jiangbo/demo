const std = @import("std");
const zhu = @import("zhu");

const context = @import("context.zig");
const spawn = @import("spawn.zig");
const title = @import("title.zig");

const system = struct {
    const crop = @import("system/crop.zig");
    const render = @import("system/render.zig");
    const ysort = @import("system/ysort.zig");
};

var farmLoaded: bool = false;

pub fn init() void {
    farmLoaded = false;
    std.log.info("scene init current={s}", .{@tagName(context.currentScene)});
}

pub fn deinit() void {
    farmLoaded = false;
}

pub fn update(registry: *zhu.ecs.Registry, delta: f32) void {
    if (context.paused) return;

    const scaled = delta * context.timeScale;
    switch (context.currentScene) {
        .title => title.update(scaled),
        .farm => updateFarm(registry, scaled),
    }

    context.applyPendingScene();
}

pub fn draw(registry: *zhu.ecs.Registry) void {
    switch (context.currentScene) {
        .title => title.draw(),
        .farm => drawFarm(registry),
    }
}

fn updateFarm(registry: *zhu.ecs.Registry, delta: f32) void {
    if (!farmLoaded) {
        spawn.loadFarm(registry);
        farmLoaded = true;
    }

    system.crop.update(registry, delta);
}

fn drawFarm(registry: *zhu.ecs.Registry) void {
    system.ysort.update(registry);
    system.render.draw(registry);
}
