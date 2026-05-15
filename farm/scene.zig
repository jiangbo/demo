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

pub fn update(World: *zhu.ecs.World, delta: f32) void {
    if (context.paused) return;

    const scaled = delta * context.timeScale;
    switch (context.currentScene) {
        .title => title.update(scaled),
        .farm => updateFarm(World, scaled),
    }

    context.applyPendingScene();
}

pub fn draw(World: *zhu.ecs.World) void {
    switch (context.currentScene) {
        .title => title.draw(),
        .farm => drawFarm(World),
    }
}

fn updateFarm(World: *zhu.ecs.World, delta: f32) void {
    if (!farmLoaded) {
        spawn.loadFarm(World);
        farmLoaded = true;
    }

    system.crop.update(World, delta);
}

fn drawFarm(World: *zhu.ecs.World) void {
    system.ysort.update(World);
    system.render.draw(World);
}
