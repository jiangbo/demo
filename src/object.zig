pub const Object = struct {
    desc: []const u8,
    tag: []const u8,
    location: ?*const Object = null,
};

const field = Object{ .desc = "an open field", .tag = "field" };
const cave = Object{ .desc = "a little cave", .tag = "cave" };
pub const objs = [_]Object{
    field,
    cave,
    .{ .desc = "a silver coin", .tag = "silver", .location = &field },
    .{ .desc = "a gold coin", .tag = "gold", .location = &cave },
    .{ .desc = "a burly guard", .tag = "guard", .location = &field },
    .{ .desc = "yourself", .tag = "yourself", .location = &field },
};

// comptime {
//     objs[2].location = &objs[0];
//     objs[4].location = &objs[0];
//     objs[5].location = &objs[0];
//     objs[3].location = &objs[1];
// }

pub var player: Object = objs[5];
