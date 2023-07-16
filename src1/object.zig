pub const Object = struct {
    desc: []const u8,
    location: ?*Object = null,
};

pub const Entity = enum {
    var Field: Object = .{ .desc = "an open field" };
    var Cave: Object = .{ .desc = "a little cave" };
    var Silver: Object = .{ .desc = "a silver coin", .location = &Field };
    var Gold: Object = .{ .desc = "a gold coin", .location = &Cave };
    var guard: Object = .{ .desc = "a burly guard", .location = &Field };
    pub var Player: Object = .{ .desc = "an open field", .location = &Field };
};
