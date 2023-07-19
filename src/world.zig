const std = @import("std");
const print = std.debug.print;

pub const Distance = enum {
    distSelf,
    distHeld,
    distHeldContained,
    distLocation,
    distHere,
    //
    distHereContained,
    distOverthere,
    distNotHere,
    distUnknownObject,
};

pub fn getDistance(from: *Item, to: ?*Item) Distance {
    if (to == null) {
        return .distUnknownObject;
    }
    if (from == to) {
        return .distSelf;
    }
    if (isHolding(from, to)) {
        return .distHeld;
    }
    if (isHolding(to, from)) {
        return .distLocation;
    }
    if (isHolding(from.location, to)) {
        return .distHere;
    }
    if (getPassage(from.location, to) != null) {
        return .distOverthere;
    }
    if (isHolding(from, to.?.location)) {
        return .distHeldContained;
    }
    if (isHolding(from.location, to.?.location)) {
        return .distHereContained;
    }
    return .distNotHere;
}

fn isHolding(container: ?*Item, item: ?*Item) bool {
    if (container == null or item == null) return false;
    return item.?.location == container;
}

pub fn actorHere() ?*Item {
    const location = player.location;
    for (&items) |*item| {
        if (isHolding(location, item) and item.type == .guard) {
            return item;
        }
    }
    return null;
}

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

    fn isLocate(self: *Item, location: *Item) bool {
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

    pub fn distanceWithPlayer(self: *Item) Distance {
        return getDistance(player, self);
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

pub fn getItem(noun: ?[]const u8, from: ?*Item, max: Distance) ?*Item {
    const itemType = toType(noun) orelse return null;
    for (&items) |*value| {
        if (value.type == itemType and
            @intFromEnum(getDistance(from.?, value)) <= @intFromEnum(max))
        {
            return value;
        }
    }
    return null;
}

pub fn getPassage(from: ?*Item, to: ?*Item) ?*Item {
    if (from != null and to != null) {
        for (&items) |*item| {
            if (isHolding(from, item) and item.destination == to) {
                return item;
            }
        }
    }
    return null;
}

pub fn getVisible(intention: []const u8, noun: ?[]const u8) ?*Item {
    const item = getItem(noun, player, Distance.distOverthere);
    if (item == null) {
        if (getItem(noun, player, Distance.distNotHere) == null) {
            print("I don't understand {s}.\n", .{intention});
        } else {
            print("You don't see any {s} here.\n", .{noun.?});
        }
    }

    return item;
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
