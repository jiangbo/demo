const zhu = @import("zhu");

pub const debug = @import("ui/debug.zig");
pub const dialog = @import("ui/dialog.zig");
pub const pause = @import("ui/pause.zig");
pub const save_slot = @import("ui/save_slot.zig");
pub const toolbar = @import("ui/toolbar.zig");

const light = @import("system/light.zig");
const target = @import("system/target.zig");
const time = @import("system/time.zig");

pub fn init() void {
    debug.init();
    pause.init();
    save_slot.init();
}

pub fn deinit() void {
    debug.deinit();
}

pub fn draw(world: *zhu.ecs.World) void {
    target.draw(world);
    light.draw(world);

    const previousMode = zhu.camera.mode;
    zhu.camera.mode = .window;
    defer zhu.camera.mode = previousMode;

    time.draw();
    toolbar.draw();
    dialog.draw(world);
}
