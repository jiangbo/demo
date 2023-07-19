const world = @import("world.zig");
const system = @import("system.zig");
const print = @import("std").debug.print;

pub fn executeGet(noun: ?[]const u8) void {
    const intention = "what you want to get";
    const item = world.getVisible(intention, noun);

    switch (world.getDistance(world.player, item)) {
        .distSelf => print("You should not be doing that to yourself.\n", .{}),
        .distHeld => print("You already have {s}.\n", .{item.?.desc}),
        .distOverthere => print("Too far away, move closer please.\n", .{}),
        .distUnknownObject => return,
        else => {
            if (item.?.type == .guard) {
                print("You should ask {s} nicely.\n", .{item.?.location.?.desc});
            } else {
                system.moveItem(item, world.player);
            }
        },
    }
}

pub fn executeDrop(noun: ?[]const u8) void {
    const possession = system.getPossession(world.player, "drop", noun);
    system.moveItem(possession, world.player.location);
}
pub fn executeAsk(noun: ?[]const u8) void {
    const possession = system.getPossession(world.actorHere(), "ask", noun);
    system.moveItem(possession, world.player);
}
pub fn executeGive(noun: ?[]const u8) void {
    const possession = system.getPossession(world.player, "give", noun);
    system.moveItem(possession, world.actorHere());
}

pub fn executeInventory() void {
    if (world.listAtLocation(world.player) == 0) {
        print("You are empty-handed.\n", .{});
    }
}
