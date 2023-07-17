const std = @import("std");
const world = @import("world.zig");
const getVisible = @import("noun.zig").getVisible;
const misc = @import("misc.zig");
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

    var obj = getVisible("where you want to go", noun) orelse return true;
    if (obj.location == null and obj != object.Entity.Player.location.?) {
        print("OK.\n", .{});
        object.Entity.Player.location = obj;
        return lookAround();
    } else {
        print("You can't get much closer than this.\n", .{});
    }

    return false;
}

fn listAtLocation(location: *world.Item) void {
    var count: i32 = 0;
    for (&world.items) |item| {
        if (item.isNotPlayer() and location.isNotSelf(item)) {
            if (count == 0) {
                print("You see:\n", .{});
            }
            print("{s}\n", .{location.desc});
            count += 1;
        }
    }
}
