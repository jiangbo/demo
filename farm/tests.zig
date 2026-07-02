const std = @import("std");

test {
    std.testing.refAllDecls(@import("inventory.zig"));
    std.testing.refAllDecls(@import("map.zig"));
    std.testing.refAllDecls(@import("factory.zig"));
    std.testing.refAllDecls(@import("interact.zig"));
    std.testing.refAllDecls(@import("save.zig"));
    std.testing.refAllDecls(@import("state.zig"));
    std.testing.refAllDecls(@import("ui.zig"));
    std.testing.refAllDecls(@import("system/animation.zig"));
    std.testing.refAllDecls(@import("system/control.zig"));
    std.testing.refAllDecls(@import("system/farm.zig"));
    std.testing.refAllDecls(@import("system/life.zig"));
    std.testing.refAllDecls(@import("system/light.zig"));
    std.testing.refAllDecls(@import("system/movement.zig"));
    std.testing.refAllDecls(@import("system/pickup.zig"));
    std.testing.refAllDecls(@import("system/render.zig"));
    std.testing.refAllDecls(@import("system/sound.zig"));
    std.testing.refAllDecls(@import("system/time.zig"));
    std.testing.refAllDecls(@import("system/transition.zig"));
    std.testing.refAllDecls(@import("system/wander.zig"));
}
