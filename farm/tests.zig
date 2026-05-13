const std = @import("std");

const context = @import("context.zig");
const event = @import("event.zig");
const time = @import("system/time.zig");

test {
    std.testing.refAllDeclsRecursive(context);
    std.testing.refAllDeclsRecursive(event);
}
