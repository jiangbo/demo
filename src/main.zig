const std = @import("std");
const exec = @import("parsexec.zig");
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

    while (true) {
        var input = try getInput(reader, buffer[0..]) orelse continue;
        if (std.mem.eql(u8, input, "quit")) {
            break;
        }
        const b = exec.parseAndExecute(input);
        _ = b;
    }

    print("\nBye!\n", .{});
}
