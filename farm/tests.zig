const std = @import("std");
const zhu = @import("zhu");

test {
    std.testing.refAllDeclsRecursive(@import("context.zig"));
    std.testing.refAllDeclsRecursive(@import("map.zig"));
    std.testing.refAllDeclsRecursive(@import("factory.zig"));
    std.testing.refAllDeclsRecursive(@import("save.zig"));
    std.testing.refAllDeclsRecursive(@import("ui/save_slot.zig"));
    std.testing.refAllDeclsRecursive(@import("system.zig"));
}
