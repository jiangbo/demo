const Type = enum { Field, Cave, Silver, Gold, Guard, Player };

pub const Item = struct {
    desc: []const u8,
    type: Type,
    location: ?*Item = null,

    pub fn isNotPlayer(self: *Item) bool {
        return self.type != .Player;
    }

    pub fn isLocation(self: *Item) bool {
        return self.type == .Field or self.type == .Cave;
    }

    pub fn isNotSelf(self: *Item, item: *Item) bool {
        return self == item;
    }

    pub fn toEnum() void {
        @stringToEnum();
    }
};

pub var items = [_]Item{
    .{ .desc = "an open field", .type = .Field },
    .{ .desc = "a little cave", .type = .Cave },
    .{ .desc = "a silver coin", .type = .Silver },
    .{ .desc = "a gold coin", .type = .Gold },
    .{ .desc = "a burly guard", .type = .Guard },
    .{ .desc = "an open field", .type = .Player },
};

pub var player: *Item = &items[5];

pub fn init() void {
    items[2].location = &items[0];
    items[3].location = &items[1];
    items[4].location = &items[0];
    items[5].location = &items[0];
}
