const std = @import("std");
const print = std.debug.print;

const Type = enum { field, cave, silver, gold, guard, player };

pub const Item = struct {
    desc: []const u8,
    type: Type,
    location: ?*const Item = null,

    pub fn isNotPlayer(self: *const Item) bool {
        return self.type != .player;
    }

    pub fn isLocation(self: *const Item) bool {
        return self.type == .field or self.type == .cave;
    }

    pub fn isLocate(self: *const Item, location: *const Item) bool {
        return self.location == location;
    }

    pub fn isPlayerNotIn(self: *const Item) bool {
        return self != player.location.?;
    }
};

pub var items = [_]Item{
    .{ .desc = "an open field", .type = .field },
    .{ .desc = "a little cave", .type = .cave },
    .{ .desc = "a silver coin", .type = .silver },
    .{ .desc = "a gold coin", .type = .gold },
    .{ .desc = "a burly guard", .type = .guard },
    .{ .desc = "yourself", .type = .player },
};

fn toType(noun: []const u8) ?Type {
    return std.meta.stringToEnum(Type, noun);
}

pub fn getItem(noun: []const u8) ?*const Item {
    const itemType = toType(noun) orelse return null;
    for (items) |*value| {
        if (value.type == itemType) {
            return value;
        }
    }
    return null;
}

pub var player: *Item = &items[5];

pub fn init() void {
    items[2].location = &items[0];
    items[3].location = &items[1];
    items[4].location = &items[0];
    items[5].location = &items[0];
}
