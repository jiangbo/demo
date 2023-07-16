const std = @import("std");
const object = @import("object.zig");
const getVisible = @import("noun.zig").getVisible;
const misc = @import("misc.zig");
const print = std.debug.print;

pub fn executeLook(input: ?[]const u8) bool {
    const noun = input orelse return false;
    if (std.mem.eql(u8, noun, "around")) {
        const player = object.Entity.Player;
        print("You are in {s}.\n", .{player.location.?.desc});
        _ = misc.listAtLocation(player.location.?);
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
