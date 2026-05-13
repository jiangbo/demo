const std = @import("std");

const context = @import("context.zig");
const event = @import("event.zig");
const spawn = @import("spawn.zig");
const crop = @import("system/crop.zig");
const time = @import("system/time.zig");

test {
    std.testing.refAllDeclsRecursive(context);
    std.testing.refAllDeclsRecursive(event);
    std.testing.refAllDeclsRecursive(spawn);
    std.testing.refAllDeclsRecursive(crop);
}
