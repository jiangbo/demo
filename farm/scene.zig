const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const map = @import("map.zig");
const spawn = @import("spawn.zig");
const title = @import("title.zig");
const inventory = @import("inventory.zig");
const toolbar = @import("ui/toolbar.zig");

const system = struct {
    const animation = @import("system/animation.zig");
    const camera = @import("system/camera.zig");
    const control = @import("system/control.zig");
    const crop = @import("system/crop.zig");
    const depth = @import("system/depth.zig");
    const movement = @import("system/movement.zig");
    const pickup = @import("system/pickup.zig");
    const render = @import("system/render.zig");
    const target = @import("system/target.zig");
    const tool = @import("system/tool.zig");
};

var farmLoaded: bool = false;

pub fn init() void {
    farmLoaded = false;
    std.log.info("scene init current={s}", .{@tagName(context.currentScene)});
}

pub fn deinit() void {
    farmLoaded = false;
}

pub fn update(world: *zhu.ecs.World, delta: f32) void {
    if (context.paused) return;

    const scaled = delta * context.timeScale;
    switch (context.currentScene) {
        .title => title.update(scaled),
        .farm => updateFarm(world, scaled),
    }

    context.applyPendingScene();
}

pub fn draw(world: *zhu.ecs.World) void {
    switch (context.currentScene) {
        .title => title.draw(),
        .farm => drawFarm(world),
    }
}

fn updateFarm(world: *zhu.ecs.World, delta: f32) void {
    if (!farmLoaded) {
        spawn.loadFarm(world);
        inventory.init();
        rebuildCells(world);
        zhu.camera.bound = map.data.size();
        farmLoaded = true;
    }

    updateToolSelection();

    system.control.update(world);
    system.movement.update(world, delta);
    system.animation.update(world, delta);
    system.crop.update(world, delta);
    system.depth.update(world);
    system.pickup.update(world);

    if (context.uiWantCaptureMouse) {
        const player = world.getIdentityEntity(component.Player).?;
        world.getPtr(player, component.Target).?.active = false;
        return;
    }

    system.camera.update(world);
    system.target.update(world);
    system.tool.update(world);
}

fn drawFarm(world: *zhu.ecs.World) void {
    map.draw();
    system.render.draw(world);
    system.target.draw(world);

    zhu.camera.mode = .fixed;
    toolbar.draw();
    zhu.window.drawDebugInfo();
    zhu.camera.mode = .world;
}

fn rebuildCells(world: *zhu.ecs.World) void {
    for (map.cells) |*cell| cell.crop = null;

    var query = world.query(.{ component.Position, component.Crop });
    while (query.next()) |entity| {
        const position = query.get(entity, component.Position);
        const cell = map.getCell(position) orelse continue;
        cell.crop = entity;
    }
}

fn updateToolSelection() void {
    if (context.uiWantCaptureKeyboard) return;

    if (zhu.input.key.pressed(._1)) inventory.active = 0;
    if (zhu.input.key.pressed(._2)) inventory.active = 1;
    if (zhu.input.key.pressed(._3)) inventory.active = 2;
    if (zhu.input.key.pressed(._4)) inventory.active = 3;
    if (zhu.input.key.pressed(._5)) inventory.active = 4;

    const scroll = zhu.input.mouseScrollY;
    if (scroll != 0) {
        const len: u32 = @intCast(inventory.slots.len);
        if (scroll > 0) {
            inventory.active = (inventory.active + len - 1) % len;
        } else {
            inventory.active = (inventory.active + 1) % len;
        }
    }

    context.tool = inventory.activeTool() orelse context.tool;
}
