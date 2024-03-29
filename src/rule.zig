const std = @import("std");
const SliceReader = @import("reader.zig").SliceReader;

const Rule = struct {
    a: u32,
    b: u16,
};

pub const Rules = struct {
    allocator: std.mem.Allocator,
    rules: []Rule,

    pub fn init(allocator: std.mem.Allocator, bytes: []const u8) !Rules {
        var reader = SliceReader.init(bytes);
        const rules = try allocator.alloc(Rule, reader.read(u16));
        for (rules) |*value| {
            value.* = .{ .a = reader.read(u32), .b = reader.read(u16) };
        }
        return Rules{ .allocator = allocator, .rules = rules };
    }

    pub fn deinit(self: Rules) void {
        self.allocator.free(self.rules);
    }
};
