const std = @import("std");
const location = @import("location.zig");
const inventory = @import("inventory.zig");
const print = std.debug.print;

pub fn main() !void {
    print("Welcome to Little Cave Adventure.\n", .{});
    const reader = std.io.getStdIn().reader();
    _ = location.lookAround();
    var buffer: [100]u8 = undefined;

    while (true) {
        print("--> ", .{});
        var input = try getInput(reader, buffer[0..]) orelse continue;
        if (std.mem.eql(u8, input, "quit")) {
            break;
        }
        parseAndExecute(input);
    }

    print("\nBye!\n", .{});
}

fn getInput(reader: anytype, buffer: []u8) !?[]const u8 {
    if (try reader.readUntilDelimiterOrEof(buffer, '\n')) |input| {
        if (@import("builtin").os.tag == .windows) {
            return std.mem.trimRight(u8, input, "\r");
        }
        return input;
    }
    return null;
}

const Action = enum {
    look,
    go,
    get,
    drop,
    give,
    ask,
    inventory,
};

pub fn parseAndExecute(input: []const u8) void {
    var iterator = std.mem.split(u8, input, " ");
    const verb = iterator.next() orelse return;
    const noun = iterator.rest();

    if (std.mem.eql(u8, verb, "look")) {
        if (!location.executeLook(noun)) {
            print("I don't understand what you want to see.\n", .{});
        }
    } else if (std.mem.eql(u8, verb, "go")) {
        if (!location.executeGo(noun)) {
            print("I don't understand where you want to go.\n", .{});
        }
    } else if (std.mem.eql(u8, verb, "get")) {
        inventory.executeGet(noun);
    } else if (std.mem.eql(u8, verb, "drop")) {
        inventory.executeDrop(noun);
    } else if (std.mem.eql(u8, verb, "give")) {
        inventory.executeGive(noun);
    } else if (std.mem.eql(u8, verb, "ask")) {
        inventory.executeAsk(noun);
    } else if (std.mem.eql(u8, verb, "inventory")) {
        inventory.executeInventory();
    } else {
        print("I don't know how to {s}.\n", .{verb});
    }
}
