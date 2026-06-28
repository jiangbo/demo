const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();

    var args = try std.process.Args.Iterator
        .initAllocator(init.minimal.args, gpa);
    defer args.deinit();
    _ = args.skip();

    const dir = args.next() orelse return error.InvalidArgs;
    if (args.next() != null) return error.InvalidArgs;

    var folder = try std.Io.Dir.cwd().openDir(init.io, dir, .{
        .iterate = true,
    });
    defer folder.close(init.io);

    var jsonNames: std.ArrayList([]const u8) = .empty;
    var iterator = folder.iterate();
    while (try iterator.next(init.io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        try jsonNames.append(gpa, try gpa.dupe(u8, entry.name));
    }
    std.mem.sortUnstable([]const u8, jsonNames.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    const sources = try gpa.alloc(Source, jsonNames.items.len);
    for (sources, jsonNames.items) |*source, name| {
        const path = try join(gpa, dir, name);
        const content = try std.Io.Dir.cwd().readFileAlloc( //
            init.io, path, gpa, .unlimited);
        source.* = .{ .path = path, .content = content };
    }

    const font = try build(gpa, sources);
    const output = try join(gpa, dir, "font.zon");
    const file = try std.Io.Dir.cwd().createFile(init.io, output, .{});
    defer file.close(init.io);

    var buffer: [4096]u8 = undefined;
    var writer = file.writer(init.io, &buffer);
    try std.zon.stringify.serialize(font, .{}, &writer.interface);
    try writer.interface.flush();
}

fn build(gpa: std.mem.Allocator, sources: []const Source) !Font {
    var images: std.ArrayList([:0]const u8) = .empty;
    var pages: std.ArrayList(Page) = .empty;

    var fontSize: ?f32 = null;
    var lineHeight: ?f32 = null;
    var imageSize: ?Vec2 = null;

    for (sources) |file| {
        const parse = std.json.parseFromSlice;
        const json = try parse(SourceFont, gpa, file.content, .{});
        const source = json.value;
        std.debug.assert(std.mem.eql(u8, source.atlas.yOrigin, "top"));

        const size = source.atlas.size;
        const pageLineHeight = source.metrics.lineHeight * size;
        const pageImageSize = Vec2{
            .x = @floatFromInt(source.atlas.width),
            .y = @floatFromInt(source.atlas.height),
        };

        if (fontSize) |value| std.debug.assert(value == size) else {
            fontSize = size;
        }
        if (lineHeight) |value| std.debug.assert(value == pageLineHeight) else {
            lineHeight = pageLineHeight;
        }
        if (imageSize) |value| {
            std.debug.assert(value.x == pageImageSize.x);
            std.debug.assert(value.y == pageImageSize.y);
        } else imageSize = pageImageSize;

        const chars = try gpa.alloc(Char, source.glyphs.len);
        for (chars, source.glyphs) |*char, glyph| {
            const advance = if (glyph.unicode < 128) size / 2 else size;
            if (@abs(glyph.advance * size - advance) > 0.01) @panic("advance");

            const bounds = glyph.atlasBounds;
            const plane = glyph.planeBounds;
            char.* = .{
                .id = glyph.unicode,
                .rect = .{
                    .min = .{ .x = bounds.left, .y = bounds.top },
                    .size = .{
                        .x = bounds.right - bounds.left,
                        .y = bounds.bottom - bounds.top,
                    },
                },
                .offset = .{
                    .x = plane.left * size,
                    .y = (-source.metrics.ascender + plane.top) * size,
                },
            };
        }
        sortChars(chars);

        try images.append(gpa, try imageName(gpa, file.path));
        try pages.append(gpa, .{
            .min = chars[0].id,
            .max = chars[chars.len - 1].id,
            .chars = chars,
        });
    }

    return .{
        .size = fontSize.?,
        .lineHeight = lineHeight.?,
        .imageSize = imageSize.?,
        .images = images.items,
        .pages = pages.items,
    };
}

fn join(gpa: std.mem.Allocator, dir: []const u8, name: []const u8) ![:0]const u8 {
    const result = try gpa.allocSentinel(u8, dir.len + 1 + name.len, 0);
    @memcpy(result[0..dir.len], dir);
    result[dir.len] = '/';
    @memcpy(result[dir.len + 1 ..][0..name.len], name);
    return result;
}

fn imageName(gpa: std.mem.Allocator, jsonName: []const u8) ![:0]const u8 {
    var normalized = try gpa.dupe(u8, jsonName);
    for (normalized) |*char| {
        if (char.* == '\\') char.* = '/';
    }

    const root = "assets/";
    const name = if (std.mem.startsWith(u8, normalized, root))
        normalized[root.len..]
    else
        normalized;
    if (!std.mem.endsWith(u8, name, ".json")) return error.InvalidArgs;

    const base = name[0 .. name.len - ".json".len];
    const result = try gpa.allocSentinel(u8, base.len + ".png".len, 0);
    @memcpy(result[0..base.len], base);
    @memcpy(result[base.len..], ".png");
    return result;
}

fn sortChars(chars: []Char) void {
    std.mem.sortUnstable(Char, chars, {}, struct {
        fn lessThan(_: void, a: Char, b: Char) bool {
            return a.id < b.id;
        }
    }.lessThan);
}

const Vec2 = struct { x: f32, y: f32 };
const Rect = struct { min: Vec2, size: Vec2 };

const Source = struct { path: []const u8, content: []const u8 };

const SourceFont = struct {
    atlas: SourceAtlas,
    metrics: SourceMetrics,
    glyphs: []const SourceGlyph,
    kerning: []const std.json.Value = &.{},
};

const SourceAtlas = struct {
    type: []const u8,
    size: f32,
    width: u32,
    height: u32,
    yOrigin: []const u8,
};

const SourceMetrics = struct {
    emSize: f32,
    lineHeight: f32,
    ascender: f32,
    descender: f32,
    underlineY: f32,
    underlineThickness: f32,
};

const SourceGlyph = struct {
    unicode: u32,
    advance: f32,
    planeBounds: SourceRect = .{},
    atlasBounds: SourceRect = .{},
};

const SourceRect = struct {
    left: f32 = 0,
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,
};

const Font = struct {
    size: f32,
    lineHeight: f32,
    imageSize: Vec2,
    images: []const [:0]const u8,
    pages: []const Page,
};

const Page = struct {
    min: u32,
    max: u32,
    chars: []const Char,
};

const Char = struct {
    id: u32,
    rect: Rect,
    offset: Vec2,
};
