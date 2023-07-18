const world = @import("world.zig");
const system = @import("system.zig");
const print = @import("std").debug.print;

pub fn executeGet(noun: ?[]const u8) void {
    const intention = "what you want to get";
    const item = world.getVisible(intention, noun) orelse return;
    if (item.isPlayer()) {
        print("You should not be doing that to yourself.\n", .{});
    } else if (item.isPlayerItem()) {
        print("You already have {s}.\n", .{item.desc});
    } else if (item.isNpcItem()) {
        print("You should ask {s} nicely.\n", .{item.location.?.desc});
    } else {
        system.moveItem(item, world.player);
    }
}

pub fn executeDrop(noun: ?[]const u8) void {
    const possession = system.getPossession(world.player, "drop", noun);
    system.moveItem(possession, world.player.location);
}
pub fn executeAsk(noun: ?[]const u8) void {
    const possession = system.getPossession(actorHere(), "ask", noun);
    system.moveItem(possession, world.player);
}
pub fn executeGive(noun: ?[]const u8) void {
    const possession = system.getPossession(world.player, "give", noun);
    system.moveItem(possession, actorHere());
}

pub fn executeInventory() void {
    if (world.listAtLocation(world.player) == 0) {
        print("You are empty-handed.\n", .{});
    }
}

fn actorHere() ?*world.Item {
    const location = world.player.location;
    for (&world.items) |*item| {
        if (item.location == location and item.type == .guard) {
            return item;
        }
    }
    return null;
}
