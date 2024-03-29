const std = @import("std");
const SliceReader = @import("reader.zig").SliceReader;
const Rules = @import("rule.zig").Rules;

const rpg = @embedFile("cartoon.rpg")[24..];

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const ruleFile = @embedFile("cartoon.rule");
    const rules = try Rules.init(gpa.allocator(), ruleFile);
    defer rules.deinit();

    var reader = SliceReader.init(rpg);
    for (rules.rules, 0..) |value, ruleIndex| {
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
        // print2dSlice(slice);

        if (typeNumber == 0) {
            try genPng(slice, ruleIndex);
        } else {
            std.log.info("type number not zero", .{});
            var r = SliceReader.init(slice[0]);
            const l = r.read(u8);
            std.log.info("byte: {}", .{r.read(u8)});
            std.log.info("x: {}", .{r.read(u16)});
            std.log.info("y: {}", .{r.read(u16)});
            std.log.info("width: {}", .{r.read(u16)});
            std.log.info("height: {}", .{r.read(u16)});

            // const nonZero = try allocator.alloc([]u8, l);
            for (0..l) |index| {
                const b2 = r.read(i8);
                std.log.info("index: {}, b2: {}", .{ index, b2 });
                // if (b2 > 0) {
                //     nonZero[index] =
                // }
            }
        }
    }
}

fn print2dSlice(slices: [][]const u8) void {
    for (slices) |slice| {
        std.debug.print("length: {}  | ", .{slice.len});
        for (slice) |value| {
            std.debug.print("{} ", .{value});
        }
        std.debug.print("\n", .{});
    }
}

const pngHeader = [_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };
const pngEnd = [_]u8{ 0, 0, 0, 0, 73, 69, 78, 68, 0b10101110, 66, 96, 0b10000010 };

const headerType = [_][]const u8{ "sBIT", "IHDR", "PLTE", "tRNS", "IDAT" };

fn genPng(slices: [][]const u8, ruleIndex: usize) !void {
    var buf: [10]u8 = undefined;
    const name = try std.fmt.bufPrint(&buf, "test{}.png", .{ruleIndex});
    var file = try std.fs.cwd().createFile(name, .{});
    defer file.close();
    var bufferWriter = std.io.bufferedWriter(file.writer());
    const writer = bufferWriter.writer();
    _ = try writer.write(&pngHeader);

    if (slices[0].len <= 4) {
        for (1..slices.len) |i| {
            const length: u32 = @intCast(slices[i].len - 4);
            _ = try writer.writeInt(u32, length, .big);
            _ = try writer.write(headerType[if (i > 4) 4 else i]);
            _ = try writer.write(slices[i]);
        }
    }

    _ = try writer.write(&pngEnd);
    try bufferWriter.flush();
}
