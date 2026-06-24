const std = @import("std");

test {
    std.testing.refAllDeclsRecursive(@import("context.zig"));
    std.testing.refAllDeclsRecursive(@import("inventory.zig"));
    std.testing.refAllDeclsRecursive(@import("map.zig"));
    std.testing.refAllDeclsRecursive(@import("factory.zig"));
    std.testing.refAllDeclsRecursive(@import("interact.zig"));
    std.testing.refAllDeclsRecursive(@import("save.zig"));
    std.testing.refAllDeclsRecursive(@import("ui.zig"));
    std.testing.refAllDeclsRecursive(@import("ui/save_slot.zig"));
    std.testing.refAllDeclsRecursive(@import("system/animation.zig"));
    std.testing.refAllDeclsRecursive(@import("system/control.zig"));
    std.testing.refAllDeclsRecursive(@import("system/farm.zig"));
    std.testing.refAllDeclsRecursive(@import("system/life.zig"));
    std.testing.refAllDeclsRecursive(@import("system/light.zig"));
    std.testing.refAllDeclsRecursive(@import("system/movement.zig"));
    std.testing.refAllDeclsRecursive(@import("system/pickup.zig"));
    std.testing.refAllDeclsRecursive(@import("system/render.zig"));
    std.testing.refAllDeclsRecursive(@import("system/sound.zig"));
    std.testing.refAllDeclsRecursive(@import("system/time.zig"));
    std.testing.refAllDeclsRecursive(@import("system/transition.zig"));
    std.testing.refAllDeclsRecursive(@import("system/wander.zig"));
}
