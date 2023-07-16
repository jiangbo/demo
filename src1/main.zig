const std = @import("std");
const exec = @import("parsexec.zig");
const location = @import("location.zig");
const noun = @import("noun.zig");
const object = @import("object.zig");
const print = std.debug.print;

fn getInput(reader: anytype, buffer: []u8) !?[]const u8 {
    if (try reader.readUntilDelimiterOrEof(buffer, '\n')) |input| {
        if (@import("builtin").os.tag == .windows) {
            return std.mem.trimRight(u8, input, "\r");
        }
        return input;
    }
    return null;
}

pub fn main() !void {
    print("Welcome to Little Cave Adventure.\n", .{});
    const reader = std.io.getStdIn().reader();
    var buffer: [100]u8 = undefined;
    _ = location.lookAround();

    while (true) {
        print("--> ", .{});
        var input = try getInput(reader, buffer[0..]) orelse continue;
        if (std.mem.eql(u8, input, "quit")) {
            break;
        }
        exec.parseAndExecute(input);
    }

    print("\nBye!\n", .{});
}
