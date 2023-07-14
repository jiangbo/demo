const std = @import("std");
const object = @import("object.zig");
const getVisible = @import("noun.zig").getVisible;
const player = object.player;
const print = std.debug.print;

pub fn executeLook(input: ?[]const u8) bool {
    const noun = input orelse return false;
    if (std.mem.eql(u8, noun, "around")) {
        print("You are in {s}.\n", .{player.location.desc});
        return true;
    }
    return false;
}

pub fn executeGo(input: ?[]const u8) bool {
    const noun = input orelse return false;
    const obj = getVisible("where you want to go", noun) orelse return true;

    if (obj.location == null and obj != player.location) {
        print("OK.\n", .{});
        player.location = obj;
        executeLook("around");
    } else {
        print("You can't get much closer than this.\n", .{});
    }

    return false;
}
