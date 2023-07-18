const std = @import("std");
const print = std.debug.print;

const Type = enum { field, cave, silver, gold, guard, player, entrance, exit };

pub const Item = struct {
    desc: []const u8,
    type: Type,
    location: ?*Item = null,
    destination: ?*Item = null,

    pub fn isPlayer(self: *Item) bool {
        return self.type == .player;
    }

    pub fn isLocation(self: *Item) bool {
        return self.location == null;
    }

    pub fn isLocate(self: *Item, location: *Item) bool {
        return self.location == location;
    }

    pub fn isPlayerIn(self: *Item) bool {
        return self == player.location;
    }

    pub fn isPlayerItem(self: *Item) bool {
        return self.location == player;
    }

    pub fn isNpcItem(self: *Item) bool {
        const location = self.location orelse return false;
        return location.type == .guard;
    }

    pub fn isWithPlayer(self: *Item) bool {
        return self.isLocate(player.location.?);
    }
};

pub var items = [_]Item{
    .{ .desc = "an open field", .type = .field },
    .{ .desc = "a little cave", .type = .cave },
    .{ .desc = "a silver coin", .type = .silver },
    .{ .desc = "a gold coin", .type = .gold },
    .{ .desc = "a burly guard", .type = .guard },
    .{ .desc = "yourself", .type = .player },
    .{ .desc = "a cave entrance", .type = .entrance },
    .{ .desc = "an exit", .type = .exit },
};

fn toType(noun: ?[]const u8) ?Type {
    return std.meta.stringToEnum(Type, noun orelse return null);
}

pub fn getItem(noun: ?[]const u8) ?*Item {
    const itemType = toType(noun) orelse return null;
    for (&items) |*value| {
        if (value.type == itemType) {
            return value;
        }
    }
    return null;
}

pub fn getVisible(intention: []const u8, noun: ?[]const u8) ?*Item {
    const oitem = getItem(noun);
    if (oitem == null) {
        print("I don't understand {s}.\n", .{intention});
        return null;
    }
    const item = oitem.?;
    if (item.isPlayer() or item.isPlayerIn() or item.isPlayerItem() or
        //
        item.isWithPlayer() or item.isLocation() or
        //
        item.location.?.isPlayerItem() or item.location.?.isWithPlayer())
    {
        return item;
    }

    print("You don't see any {s} here.\n", .{noun.?});
    return null;
}

pub fn listAtLocation(location: *Item) usize {
    var count: usize = 0;
    for (&items) |*item| {
        if (!item.isPlayer() and item.isLocate(location)) {
            if (count == 0) {
                print("You see:\n", .{});
            }
            print("{s}\n", .{item.desc});
            count += 1;
        }
    }
    return count;
}

pub var player: *Item = &items[5];

pub fn init() void {
    items[2].location = &items[0];
    items[3].location = &items[1];
    items[4].location = &items[0];
    items[5].location = &items[0];

    items[6].location = &items[0];
    items[6].destination = &items[1];

    items[7].location = &items[1];
    items[7].destination = &items[0];
}
