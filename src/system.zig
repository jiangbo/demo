const world = @import("world.zig");
const print = @import("std").debug.print;

pub fn moveItem(obj: ?*world.Item, to: ?*world.Item) void {
    const from = obj orelse return;

    if (to == null) {
        return print("There is nobody here to give that to.\n", .{});
    }

    if (from.isLocation()) {
        return print("That is way too heavy.\n", .{});
    }

    describeMove(from, to.?);
    from.location = to;
}

fn describeMove(from: *world.Item, to: *world.Item) void {
    if (to == world.player.location) {
        print("You drop {s}.\n", .{from.desc});
    } else if (to != world.player) {
        if (to.type == .guard) {
            print("You give {s} to {s}.\n", .{ from.desc, to.desc });
        } else {
            print("You put {s} in {s}.\n", .{ from.desc, to.desc });
        }
    } else if (from.isWithPlayer()) {
        print("You pick up {s}.\n", .{from.desc});
    } else {
        print("You get {s} from {s}.\n", .{ from.desc, from.location.?.desc });
    }
}

pub fn getPossession(from: ?*world.Item, verb: []const u8, noun: ?[]const u8) ?*world.Item {
    if (from == null) {
        print("I don't understand who you want to {s}.\n", .{verb});
        return null;
    }

    const max = world.Distance.distHeldContained;
    const item = world.getItem(noun, from, max);
    if (item == null) {
        if (world.getItem(noun, world.player, world.Distance.distNotHere) == null) {
            print("I don't understand what you want to {s}.\n", .{verb});
        } else if (from == world.player) {
            print("You are not holding any {s}.\n", .{noun.?});
        } else {
            print("There appears to be no {s} you can get from {s}.\n", .{ noun.?, from.?.desc });
        }
    } else {
        if (item.?.isAmbiguous()) {
            print("Please be specific about which {s} you want to {s}.\n", .{ noun.?, verb });
            return null;
        } else if (item == from) {
            print("You should not be doing that to {s}.\n", .{item.?.desc});
            return null;
        }
    }
    return item;
}
