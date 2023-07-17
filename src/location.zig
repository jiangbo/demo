const std = @import("std");
const world = @import("world.zig");
const getVisible = @import("noun.zig").getVisible;
const print = std.debug.print;

pub fn executeLook(input: ?[]const u8) bool {
    const noun = input orelse return false;
    if (std.mem.eql(u8, noun, "around")) {
        const location = world.player.location.?;
        print("You are in {s}.\n", .{location.desc});
        listAtLocation(location);
        return true;
    }
    return false;
}

pub fn lookAround() bool {
    return executeLook("around");
}

pub fn executeGo(input: ?[]const u8) bool {
    const noun = input orelse return false;

    var item = world.getItem(noun) orelse return false;
    if (item.isLocation() and item.isPlayerNotIn()) {
        print("OK.\n", .{});
        world.player.location = item;
        return lookAround();
    } else {
        print("You can't get much closer than this.\n", .{});
        return true;
    }

    return false;
}

fn listAtLocation(location: *const world.Item) void {
    var count: i32 = 0;
    for (world.items) |item| {
        if (item.isNotPlayer() and item.isLocate(location)) {
            if (count == 0) {
                print("You see:\n", .{});
            }
            print("{s}\n", .{item.desc});
            count += 1;
        }
    }
}
