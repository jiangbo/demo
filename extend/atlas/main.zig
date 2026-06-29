const std = @import("std");

const atlas = @import("atlas.zig");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();

    var args = try std.process.Args.Iterator
        .initAllocator(init.minimal.args, gpa);
    defer args.deinit();
    _ = args.skip();

    const firstName = args.next() orelse return error.InvalidArgs;
    if (args.next() != null) return error.InvalidArgs;

    var context = Context{ .io = init.io, .gpa = gpa };

    const dir = std.fs.path.dirname(firstName) orelse ".";
    const output = try std.fs.path.join(gpa, &.{ dir, "atlas.zon" });
    try readPage(&context, firstName);

    const content = try std.Io.Dir.cwd().readFileAlloc(init.io, //
        firstName, gpa, .unlimited);
    const json = try parseFromSlice(std.json.Value, gpa, content, .{});
    const metaJson = json.value.object.get("meta").?;
    const meta = try parseFromValue(atlas.Meta, gpa, metaJson, .{});

    if (meta.value.related_multi_packs) |multiPacks| {
        for (multiPacks) |name| {
            const pageName = try std.fs.path.join(gpa, &.{ dir, name });
            try readPage(&context, pageName);
        }
    }

    std.mem.sortUnstable(Image, context.images.items, {}, struct {
        fn lessThan(_: void, image1: Image, image2: Image) bool {
            return image1.view.id < image2.view.id;
        }
    }.lessThan);

    const result = Atlas{
        .imagePaths = context.pageNames.items,
        .size = .{ .x = meta.value.size.w, .y = meta.value.size.h },
        .images = context.images.items,
    };

    const file = try std.Io.Dir.cwd().createFile(init.io, output, .{});
    defer file.close(init.io);
    var buffer: [4096]u8 = undefined;
    var writer = file.writer(init.io, &buffer);
    try std.zon.stringify.serialize(result, .{}, &writer.interface);
    try writer.interface.flush();
}
const parseFromSlice = std.json.parseFromSlice;
const parseFromValue = std.json.parseFromValue;

const Context = struct {
    io: std.Io,
    gpa: std.mem.Allocator,
    checkIdRepeat: std.AutoHashMapUnmanaged(u32, void) = .empty,
    pageNames: std.ArrayList([]const u8) = .empty,
    images: std.ArrayList(Image) = .empty,
};

fn readPage(context: *Context, name: []const u8) !void {
    const gpa = context.gpa;
    const layer: u32 = @intCast(context.pageNames.items.len);
    std.log.info("file name: {s}", .{name});

    const content = try std.Io.Dir.cwd().readFileAlloc( //
        context.io, name, gpa, .unlimited);
    const json = try parseFromSlice(std.json.Value, gpa, content, .{});
    const root = json.value.object;

    const metaJson = root.get("meta").?;
    const meta = (try parseFromValue(atlas.Meta, gpa, metaJson, .{})).value;
    const print = std.fmt.allocPrint;
    const imagePath = try print(gpa, "atlas/{s}", .{meta.image});
    try context.pageNames.append(gpa, imagePath);

    const framesObject = root.get("frames").?.object;
    var iterator = framesObject.iterator();
    while (iterator.next()) |entry| {
        const filename = entry.key_ptr.*;
        const imageId = std.hash.Fnv1a_32.hash(filename);
        std.log.info("{s} -> {}", .{ filename, imageId });
        if (context.checkIdRepeat.contains(imageId)) {
            std.debug.panic("{s},{} repeat", .{ filename, imageId });
        }
        try context.checkIdRepeat.put(gpa, imageId, {});

        const frame = (try parseFromValue(atlas.AtlasFrame, //
            gpa, entry.value_ptr.*, .{})).value.frame;
        try context.images.append(gpa, .{
            .view = .{ .id = imageId },
            .layer = layer,
            .offset = .{ .x = frame.x, .y = frame.y },
            .size = .{ .x = frame.w, .y = frame.h },
        });
    }
}

const Vec2 = struct { x: i32, y: i32 };
const View = struct { id: u32 };
const Image = struct {
    view: View,
    layer: u32,
    offset: Vec2,
    size: Vec2,
};
pub const Atlas = struct {
    imagePaths: []const []const u8,
    size: Vec2,
    images: []const Image,
};
