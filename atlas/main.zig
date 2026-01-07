const std = @import("std");

const atlas = @import("atlas.zig");

pub fn main() !void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debugAllocator.deinit();
    var arena = std.heap.ArenaAllocator.init(debugAllocator.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    if (args.len != 2) return error.invalidArgs;
    const name = args[1];
    std.log.info("file name: {s}", .{name});

    const max = std.math.maxInt(usize);
    const content = try std.fs.cwd().readFileAlloc(allocator, name, max);

    const json = try std.json.parseFromSlice(atlas.Atlas, allocator, content, .{});
    const value = json.value;

    // 写入 font.zon 文件
    const outputName = try std.mem.replaceOwned(u8, allocator, name, ".json", ".zon");
    const file = try std.fs.cwd().createFile(outputName, .{});
    defer file.close();
    var buffer: [4096]u8 = undefined;
    var writer = file.writer(&buffer);

    const images = try allocator.alloc(Image, value.frames.len);
    var checkIdRepeat: std.AutoHashMapUnmanaged(u32, void) = .empty;
    for (images, value.frames) |*image, frame| {
        image.id = std.hash.Fnv1a_32.hash(frame.filename);
        if (checkIdRepeat.contains(image.id)) {
            std.debug.panic("{s},{} repeat", .{ frame.filename, image.id });
        } else try checkIdRepeat.put(allocator, image.id, {});
        image.area.min = .{ .x = frame.frame.x, .y = frame.frame.y };
        image.area.size = .{ .x = frame.frame.w, .y = frame.frame.h };
    }

    const result = Atlas{
        .imagePath = value.meta.image,
        .size = .{
            .x = value.meta.size.w,
            .y = value.meta.size.h,
        },
        .images = images,
    };

    try std.zon.stringify.serialize(result, .{}, &writer.interface);
    try writer.interface.flush();
}

const Vec2 = struct { x: i32, y: i32 };
const Image = struct {
    id: u32,
    area: struct { min: Vec2, size: Vec2 },
};
pub const Atlas = struct {
    imagePath: []const u8,
    size: Vec2,
    images: []const Image,
};
