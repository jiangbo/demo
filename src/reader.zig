const std = @import("std");

pub const SliceReader = struct {
    bytes: []const u8,
    index: usize,

    pub fn init(bytes: []const u8) SliceReader {
        return .{ .bytes = bytes, .index = 0 };
    }

    pub fn read(self: *SliceReader, comptime T: type) T {
        const size = @sizeOf(T);

        const slice = self.bytes[self.index .. self.index + size];
        const value: *align(1) const T = @ptrCast(slice);

        self.index += size;
        return std.mem.bigToNative(T, value.*);
    }

    pub fn readSlice(self: *SliceReader, size: usize) []const u8 {
        defer self.index += size;
        return self.bytes[self.index .. self.index + size];
    }
};
