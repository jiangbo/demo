const zhu = @import("zhu");

const animation = @import("system/animation.zig");
const camera = @import("system/camera.zig");
const control = @import("system/control.zig");
const crop = @import("system/crop.zig");
const light = @import("system/light.zig");
const movement = @import("system/movement.zig");
const pickup = @import("system/pickup.zig");
const render = @import("system/render.zig");
const sound = @import("system/sound.zig");
const talk = @import("system/talk.zig");
const target = @import("system/target.zig");
const time = @import("system/time.zig");
const tool = @import("system/tool.zig");
const transition = @import("system/transition.zig");
const wander = @import("system/wander.zig");

const World = zhu.ecs.World;

pub fn init() void {
    time.init();
    light.init();
}

pub fn update(world: *World, delta: f32) void {
    time.update(world, delta);
    light.update(world);
    control.update(world);
    wander.update(world, delta);
    movement.update(world, delta);
    transition.update(world);
    animation.update(world, delta);
    crop.update(world, delta);
    render.update(world);
    pickup.update(world);

    talk.update(world);
    camera.update(world);
    target.update(world);
    tool.update(world);
    sound.update(world);
}

pub fn updatePause(world: *World, delta: f32) void {
    _ = delta;
    sound.update(world);
}
