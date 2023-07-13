const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    print("Welcome to Little Cave Adventure.\n", .{});
    var buffer: [100]u8 = undefined;

    while (true) {
        var input = try getInput(buffer[0..]) orelse continue;
        if (std.mem.eql(u8, input, "quit")) {
            break;
        }
        const b = parseAndExecute(input);
        _ = b;
    }

    print("\nBye!\n", .{});
}

fn getInput(buffer: []u8) !?[]const u8 {
    const stdin = std.io.getStdIn().reader();
    if (try stdin.readUntilDelimiterOrEof(buffer[0..], '\n')) |input| {
        return std.mem.trim(u8, input, "\r");
    } else {
        return null;
    }
}

fn parseAndExecute(input: []const u8) bool {
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
