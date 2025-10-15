const std = @import("std");

pub fn main() !void {
    std.log.info("hello world", .{});

    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();

    var sparseSet: SparseSet = .empty;
    defer sparseSet.deinit(gpa.allocator());

    try sparseSet.add(gpa.allocator(), 4);
    try sparseSet.add(gpa.allocator(), 6);
    try sparseSet.add(gpa.allocator(), 0);
    sparseSet.clear();
    std.log.info("sparse set: {}", .{sparseSet});
}

const SparseSet = struct {
    dense: std.ArrayListUnmanaged(u8),
    sparse: std.ArrayListUnmanaged(u8),

    pub const empty = SparseSet{
        .dense = .empty,
        .sparse = .empty,
    };

    pub fn deinit(self: *SparseSet, allocator: std.mem.Allocator) void {
        self.dense.deinit(allocator);
        self.sparse.deinit(allocator);
    }

    pub fn add(self: *SparseSet, allocator: std.mem.Allocator, value: u8) !void {
        if (value >= self.sparse.capacity) {
            try self.sparse.ensureTotalCapacity(allocator, value + 1);
            self.sparse.expandToCapacity();
        }

        const len: u8 = @intCast(self.dense.items.len);
        try self.dense.append(allocator, value);
        self.sparse.items[value] = len;
    }

    pub fn remove(self: *SparseSet, value: u8) !void {
        const len: u8 = @intCast(self.dense.items.len);
        const index: u8 = self.sparse.items[value];
        if (index >= len) return;

        const last: u8 = self.dense.items[len - 1];
        self.dense.items[index] = last;
    }

    pub fn clear(self: *SparseSet) void {
        self.dense.clearRetainingCapacity();
    }
};
