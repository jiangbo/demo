const std = @import("std");
const world = @import("world.zig");
const print = std.debug.print;

pub fn executeGet(noun: ?[]const u8) void {
    const intention = "what you want to get";
    const item = world.getVisible(intention, noun) orelse return;
    if (item.isPlayer()) {
        print("You should not be doing that to yourself.\n", .{});
    } else if (item.isPlayerItem()) {
        print("You already have {s}.\n", .{item.desc});
    } else if (item.isNpcItem()) {
        print("You should ask {s} nicely.\n", .{item.location.?.desc});
    } else {
        world.moveItem(item, world.player);
    }
}
