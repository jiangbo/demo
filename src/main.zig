const std = @import("std");
const exec = @import("parsexec.zig");
const location = @import("location.zig");
const noun = @import("noun.zig");
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
        print("--> ", .{});
        var input = try getInput(reader, buffer[0..]) orelse continue;
        if (std.mem.eql(u8, input, "quit")) {
            break;
        }
        exec.parseAndExecute(input);
    }

    print("\nBye!\n", .{});
}

// const std = @import("std");

// pub const Object = struct {
//     desc: []const u8,
//     tag: []const u8,
//     location: ?*const Object = null,
// };

// pub const objs0 = Object{ .desc = "an open field", .tag = "field" };
// pub const objs1 = Object{ .desc = "a little cave", .tag = "cave" };
// pub const objs = [_]Object{
//     objs0,
//     objs1,
//     .{ .desc = "a silver coin", .tag = "silver", .location = &objs0 },
//     .{ .desc = "a gold coin", .tag = "gold", .location = &objs1 },
//     .{ .desc = "a burly guard", .tag = "guard", .location = &objs0 },
//     .{ .desc = "yourself", .tag = "yourself", .location = &objs0 },
// };

// pub fn main() !void {
//     if (&objs[0] == objs[2].location.?) {
//         std.debug.print("eq", .{});
//     } else {
//         std.debug.print("neq", .{});
//     }
// }
