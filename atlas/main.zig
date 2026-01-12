const std = @import("std");

const atlas = @import("atlas.zig");

pub fn main() !void {
    var debugAllocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debugAllocator.deinit();
    var arena = std.heap.ArenaAllocator.init(debugAllocator.allocator());
    defer arena.deinit();
    const a = arena.allocator();

    const args = try std.process.argsAlloc(a);
    if (args.len != 2) return error.invalidArgs;
    const name = args[1];
    std.log.info("file name: {s}", .{name});

    const max = std.math.maxInt(usize);
    const content = try std.fs.cwd().readFileAlloc(a, name, max);

    const j = std.json;
    const json = try j.parseFromSlice(j.Value, a, content, .{});
    const root = json.value.object;

    const metaJson = root.get("meta").?;
    const meta = (try j.parseFromValue(atlas.Meta, a, metaJson, .{})).value;

    // 写入 font.zon 文件
    const outputName = try std.mem.replaceOwned(u8, a, name, ".json", ".zon");
    const file = try std.fs.cwd().createFile(outputName, .{});
    defer file.close();
    var buffer: [4096]u8 = undefined;
    var writer = file.writer(&buffer);

    var images = std.ArrayList(Image).empty;

    var checkIdRepeat: std.AutoHashMapUnmanaged(u32, void) = .empty;
    const framesObject = root.get("frames").?.object;
    var iterator = framesObject.iterator();
    while (iterator.next()) |entry| {
        const filename = entry.key_ptr.*;
        var image: Image = undefined;
        image.id = std.hash.Fnv1a_32.hash(filename);
        if (checkIdRepeat.contains(image.id)) {
            std.debug.panic("{s},{} repeat", .{ filename, image.id });
        } else try checkIdRepeat.put(a, image.id, {});

        const frame = (try j.parseFromValue(atlas.AtlasFrame, a, entry.value_ptr.*, .{})).value;
        image.area.min = .{ .x = frame.frame.x, .y = frame.frame.y };
        image.area.size = .{ .x = frame.frame.w, .y = frame.frame.h };
        try images.append(a, image);
    }

    std.mem.sortUnstable(Image, images.items, {}, struct {
        fn lessThan(_: void, image1: Image, image2: Image) bool {
            return image1.id < image2.id;
        }
    }.lessThan);

    const result = Atlas{
        .imagePath = meta.image,
        .size = .{
            .x = meta.size.w,
            .y = meta.size.h,
        },
        .images = images.items,
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
