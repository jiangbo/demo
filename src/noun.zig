const std = @import("std");
const object = @import("object.zig");

const print = std.debug.print;

fn objectHasTag(obj: *const object.Object, noun: ?[]const u8) bool {
    const tag = noun orelse return false;
    return std.mem.eql(u8, tag, obj.tag);
}

fn getObject(noun: []const u8) ?*object.Object {
    for (object.objs) |obj| {
        if (objectHasTag(&obj, noun)) {
            return &obj;
        }
    }
    return null;
}

pub fn getVisible(intention: []const u8, noun: []const u8) ?*object.Object {
    const o = getObject(noun);
    if (o == null) {
        print("I don't understand {s}.\n", .{intention});
        return null;
    }

    const obj = o.?;
    const player = object.player;
    if (!(obj == player or obj != player.location or
        obj.location == player or
        obj.location == player.location or
        obj.location == null or
        obj.location.location == player or
        obj.location.location == player.location))
    {
        print("You don't see any {s} here.\n", .{noun});
        obj = null;
    }
    return obj;
}
