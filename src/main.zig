const std = @import("std");

pub fn main() !void {
    std.log.info("hello world", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();

    var sparseSet: SparseSet = .init(gpa.allocator());
    defer sparseSet.deinit();

    try sparseSet.add(4);
    try sparseSet.add(6);
    try sparseSet.add(0);
    std.log.info("sparse set: {}", .{sparseSet});

    std.log.info("has: {}", .{sparseSet.has(4)});
    sparseSet.remove(4);
    std.log.info("has: {}", .{sparseSet.has(4)});
}

const SparseSet = struct {
    dense: std.ArrayList(u8) = .empty,
    sparse: std.ArrayList(u8) = .empty,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SparseSet {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *SparseSet) void {
        self.dense.deinit(self.allocator);
        self.sparse.deinit(self.allocator);
    }

    pub fn add(self: *SparseSet, value: u8) !void {
        if (self.has(value)) return;

        if (value >= self.sparse.capacity) {
            try self.sparse.ensureTotalCapacity(self.allocator, value + 1);
            self.sparse.expandToCapacity();
        }

        const len: u8 = @intCast(self.dense.items.len);
        try self.dense.append(self.allocator, value);
        self.sparse.items[value] = len;
    }

    pub fn has(self: *SparseSet, value: u8) bool {
        if (value >= self.sparse.items.len) return false;
        const index = self.sparse.items[value];
        const items = self.dense.items;
        return index < items.len and items[index] == value;
    }

    pub fn remove(self: *SparseSet, value: u8) void {
        if (value >= self.sparse.items.len) return;

        const index: u8 = self.sparse.items[value];
        if (index >= self.dense.items.len) return;
        _ = self.dense.swapRemove(index);
    }

    pub fn clear(self: *SparseSet) void {
        self.dense.clearRetainingCapacity();
    }
};
