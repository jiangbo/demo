const std = @import("std");
const world = @import("world.zig");
const print = std.debug.print;

pub fn executeLook(input: ?[]const u8) bool {
    const noun = input orelse return false;
    if (std.mem.eql(u8, noun, "around")) {
        const location = world.player.location.?;
        print("You are in {s}.\n", .{location.desc});
        _ = world.listAtLocation(location);
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
    switch (item.distanceWithPlayer()) {
        .distOverthere => {
            print("OK.\n", .{});
            world.player.location = item;
            _ = lookAround();
        },
        .distNotHere => {
            print("2You don't see any {s} here.\n", .{noun});
        },
        .distUnknownObject => {
            return true;
        },
        else => {
            if (item.destination != null) {
                print("OK.\n", .{});
                world.player.location = item.destination;
                _ = lookAround();
            } else {
                print("You can't get much closer than this.\n", .{});
            }
        },
    }
    // if (world.getPassage(world.player.location, item) != null) {
    //     print("OK.\n", .{});
    //     world.player.location = item;
    //     return lookAround();
    // } else if (!item.isWithPlayer()) {
    //     print("You don't see any {s} here.\n", .{noun});
    // } else if (!item.isPlayerIn()) {
    //     print("OK.\n", .{});
    //     world.player.location = item.destination;
    //     return lookAround();
    // } else {
    //     print("You can't get much closer than this.\n", .{});
    //     return true;
    // }

    return true;
}
