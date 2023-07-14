const std = @import("std");
const print = std.debug.print;

pub fn parseAndExecute(input: []const u8) bool {
    var it = std.mem.split(u8, input, " ");
    const first = it.next();

    if (first) |verb| {
        if (std.mem.eql(u8, verb, "look")) {
            print("It is very dark in here.\n", .{});
        } else if (std.mem.eql(u8, verb, "go")) {
            print("It's too dark to go anywhere.\n", .{});
        } else {
            print("I don't know how to {s}.\n", .{verb});
        }
    }
    return true;
}
