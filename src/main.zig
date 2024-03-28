const std = @import("std");
const bigToNative = std.mem.bigToNative;

const rule = @embedFile("cartoon.rule");
const rpg = @embedFile("cartoon.rpg");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const number: u16 = @as(u16, rule[0]) << 8 | rule[1];
    std.log.debug("rulenumber: {}", .{number});

    const rules = try allocator.alloc(Rule, number);
    defer allocator.free(rules);
    for (0..number) |value| {
        const index = 2 + (value * 6);
        const a = rule[index..];
        const b = rule[index + 4 ..];
        rules[value] = .{ .a = sliceInt(a, u32), .b = sliceInt(b, u16) };
    }

    for (rules) |value| {
        std.log.debug("rule: {any}", .{value});
    }
}

const Rule = struct {
    a: u32,
    b: u16,
};

fn sliceInt(slice: []const u8, comptime T: type) T {
    const ptr: *align(1) const T = @ptrCast(slice[0..@sizeOf(T)]);
    return std.mem.bigToNative(T, ptr.*);
}
