const std = @import("std");
const bigToNative = std.mem.bigToNative;

const rule = @embedFile("cartoon.rule");
const rpg = @embedFile("cartoon.rpg");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const number: u16 = @as(u16, rule[0]) << 8 | rule[1];
    std.log.debug("number: {}", .{number});

    const rules = try allocator.alloc(Rule, number);
    defer allocator.free(rules);
    for (0..number) |value| {
        const index = 2 + (value * 6);
        const a = rule[index .. index + 4];
        const b = rule[index + 4 .. index + 6];
        rules[value] = .{
            .a = bigToNative(u32, @as(*align(1) const u32, @ptrCast(a)).*),
            .b = bigToNative(u16, @as(*align(1) const u16, @ptrCast(b)).*),
        };
    }

    for (rules) |value| {
        std.log.debug("rule: {any}", .{value});
    }
}

const Rule = struct {
    a: u32,
    b: u16,
};
