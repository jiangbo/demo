const std = @import("std");

const component = @import("component.zig");
const context = @import("context.zig");
const map = @import("map.zig");
const scene = @import("scene.zig");
const spawn = @import("spawn.zig");

pub fn main() void {
    context.init();
    defer context.deinit();

    map.init();
    defer map.deinit();

    spawn.init();
    defer spawn.deinit();

    scene.init();
    defer scene.deinit();

    const origin: component.Position = .zero;
    std.log.info("tiny farm scene={s} pos=({d},{d})", .{
        @tagName(context.currentScene),
        origin.x,
        origin.y,
    });
}
