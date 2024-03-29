const std = @import("std");

const rule = @embedFile("cartoon.rule");
const rpg = @embedFile("cartoon.rpg")[24..];

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var reader = SliceReader.init(rule);
    const rules = try allocator.alloc(Rule, reader.read(u16));
    defer allocator.free(rules);
    for (rules) |*value| {
        value.* = .{ .a = reader.read(u32), .b = reader.read(u16) };
    }

    reader = SliceReader.init(rpg);
    for (rules) |value| {
        std.log.info("rule: {any}", .{value});
        const typeNumber = reader.read(u8);
        std.log.info("type number: {}", .{typeNumber});

        const length = reader.read(u8);
        std.log.info("length: {}", .{length});

        const slice: [][]const u8 = try allocator.alloc([]u8, length);
        defer allocator.free(slice);
        for (0..length) |i| {
            const size = reader.read(u32);
            slice[i] = reader.readSlice(size);
        }
        print2dSlice(slice);

        if (typeNumber == 0) {
            try genPng(slice);
        } else {}

        break;
    }
}

fn print2dSlice(slices: [][]const u8) void {
    for (slices) |slice| {
        for (slice) |value| {
            std.debug.print("{} ", .{value});
        }
        std.debug.print("\n", .{});
    }
}

const pngHeader = [_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };
const pngEnd = [_]u8{ 0, 0, 0, 0, 73, 69, 78, 68, 0b10101110, 66, 96, 0b10000010 };

const headerType = [_][]const u8{ "sBIT", "IHDR", "PLTE", "tRNS", "IDAT" };

fn genPng(slices: [][]const u8) !void {
    var reader = SliceReader.init(slices[1]);

    const width = reader.read(u32);
    const height = reader.read(u32);
    std.log.info("width: {}, height: {}", .{ width, height });
    var file = try std.fs.cwd().createFile("test.png", .{});
    defer file.close();
    var bufferWriter = std.io.bufferedWriter(file.writer());
    const writer = bufferWriter.writer();

    _ = try writer.write(&pngHeader);

    if (slices[0].len <= 4) {
        for (1..slices.len) |i| {
            const length: u32 = @intCast(slices[i].len - 4);
            _ = try writer.writeInt(u32, length, .little);
            _ = try writer.write(headerType[if (i > 4) 4 else i]);
            _ = try writer.write(slices[i]);

            return;
        }
    }

    _ = try writer.write(&pngEnd);
    try bufferWriter.flush();
}

// fn writeToFile()

const Rule = struct {
    a: u32,
    b: u16,
};

const SliceReader = struct {
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
