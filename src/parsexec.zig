const std = @import("std");
const location = @import("location.zig");
const print = std.debug.print;

pub fn parseAndExecute(input: []const u8) void {
    var iterator = std.mem.split(u8, input, " ");
    const verb = iterator.next() orelse return;
    const noun = iterator.next();

    if (std.mem.eql(u8, verb, "look")) {
        if (!location.executeLook(noun)) {
            print("I don't understand what you want to see.\n", .{});
        }
    } else if (std.mem.eql(u8, verb, "go")) {
        if (!location.executeGo(noun)) {
            print("I don't understand where you want to go.\n", .{});
        }
    } else {
        print("I don't know how to {s}.\n", .{verb});
    }
}
