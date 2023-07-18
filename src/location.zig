const std = @import("std");
const world = @import("world.zig");
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

    const intention = "where you want to go";
    var item = world.getVisible(intention, noun) orelse return true;
    if (item.isLocation() and !item.isPlayerIn()) {
        print("OK.\n", .{});
        world.player.location = item;
        return lookAround();
    } else {
        print("You can't get much closer than this.\n", .{});
        return true;
    }

    return false;
}

fn listAtLocation(location: *world.Item) void {
    var count: i32 = 0;
    for (&world.items) |*item| {
        if (!item.isPlayer() and item.isLocate(location)) {
            if (count == 0) {
                print("You see:\n", .{});
            }
            print("{s}\n", .{item.desc});
            count += 1;
        }
    }
}
