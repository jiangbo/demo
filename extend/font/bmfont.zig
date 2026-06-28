const std = @import("std");

pub fn run(io: std.Io, gpa: std.mem.Allocator, args: anytype) !void {
    const inputName = args.next() orelse return error.InvalidArgs;
    const outputName = args.next() orelse return error.InvalidArgs;

    const content = try std.Io.Dir.cwd().readFileAlloc( //
        io, inputName, gpa, .unlimited);
    const source = parse(gpa, content);

    const pageCount = source.pages.len;
    const lists = try gpa.alloc(std.ArrayList(Char), pageCount);
    for (lists) |*list| list.* = .empty;

    const size = source.info.fontSize;
    const halfSize = @divExact(size, 2);
    for (source.chars) |char| {
        const advance = if (char.id < 128) halfSize else size;
        if (char.xAdvance != advance) @panic("advance");

        try lists[char.page].append(gpa, .{
            .id = char.id,
            .rect = .{
                .min = .{
                    .x = @floatFromInt(char.x),
                    .y = @floatFromInt(char.y),
                },
                .size = .{
                    .x = @floatFromInt(char.width),
                    .y = @floatFromInt(char.height),
                },
            },
            .offset = .{
                .x = @floatFromInt(char.xOffset),
                .y = @floatFromInt(char.yOffset),
            },
        });
    }

    const images = try gpa.alloc([:0]const u8, pageCount);
    const pages = try gpa.alloc(Page, pageCount);
    for (pages, source.pages, lists, 0..) |*page, image, *chars, i| {
        images[i] = try gpa.dupeZ(u8, image);
        sortChars(chars.items);
        page.* = .{
            .min = chars.items[0].id,
            .max = chars.items[chars.items.len - 1].id,
            .chars = chars.items,
        };
    }

    const result = Font{
        .size = @floatFromInt(size),
        .lineHeight = @floatFromInt(source.common.lineHeight),
        .imageSize = .{
            .x = @floatFromInt(source.common.scaleW),
            .y = @floatFromInt(source.common.scaleH),
        },
        .images = images,
        .pages = pages,
    };
    try writeZon(io, outputName, result);
}

pub fn parse(gpa: std.mem.Allocator, data: []const u8) RawFont {
    arena = gpa;
    var reader: std.Io.Reader = .fixed(data);
    doParse(&reader) catch unreachable;
    return rawFont;
}

const BlockTag = enum(u8) { none, info, common, page, char, kerning };

fn doParse(reader: *std.Io.Reader) !void {
    if (!std.mem.eql(u8, try reader.take(3), "BMF")) {
        return error.badHeader;
    }

    if (try reader.takeByte() != 3) {
        return error.incompatibleVersion;
    }

    try parseInfo(reader, try parseSize(reader, .info));
    try parseCommon(reader, try parseSize(reader, .common));
    try parsePage(reader, try parseSize(reader, .page));
    try parseChar(reader, try parseSize(reader, .char));
    try parseKerningPairs(reader, try parseSize(reader, .kerning));
}

fn parseSize(reader: *std.Io.Reader, tag: BlockTag) !usize {
    const actualInt = reader.takeByte() catch |e| {
        if (e == error.EndOfStream) return 0;
        return e;
    };
    const actual: BlockTag = @enumFromInt(actualInt);
    if (actual != tag) return error.unexpectedBlock;
    return @intCast(try reader.takeInt(i32, .little));
}

var rawFont: RawFont = undefined;
var arena: std.mem.Allocator = undefined;

fn parseInfo(reader: *std.Io.Reader, _: usize) !void {
    rawFont.info = .{
        .fontSize = @intCast(@abs(try reader.takeInt(i16, .little))),
        .bitField = try reader.takeByte(),
        .charSet = try reader.takeByte(),
        .stretchH = try reader.takeInt(u16, .little),
        .aa = try reader.takeByte(),
        .paddingUp = try reader.takeByte(),
        .paddingRight = try reader.takeByte(),
        .paddingDown = try reader.takeByte(),
        .paddingLeft = try reader.takeByte(),
        .spacingHoriz = try reader.takeByte(),
        .spacingVert = try reader.takeByte(),
        .outline = try reader.takeByte(),
    };
    rawFont.info.name = try readString(reader);
}

fn parseCommon(reader: *std.Io.Reader, _: usize) !void {
    rawFont.common = .{
        .lineHeight = try reader.takeInt(u16, .little),
        .base = try reader.takeInt(u16, .little),
        .scaleW = try reader.takeInt(u16, .little),
        .scaleH = try reader.takeInt(u16, .little),
        .pages = try reader.takeInt(u16, .little),
        .bitField = try reader.takeByte(),
        .alphaChnl = try reader.takeByte(),
        .redChnl = try reader.takeByte(),
        .greenChnl = try reader.takeByte(),
        .blueChnl = try reader.takeByte(),
    };
}

fn parsePage(reader: *std.Io.Reader, size: usize) !void {
    const end = reader.seek + size;
    var pages: std.ArrayList([]const u8) = .empty;
    while (reader.seek < end) {
        try pages.append(arena, try readString(reader));
    }
    rawFont.pages = try pages.toOwnedSlice(arena);
}

fn parseChar(reader: *std.Io.Reader, size: usize) !void {
    const len: usize = @intCast(@divExact(size, 20));

    const chars = try arena.alloc(RawChar, len);
    for (chars) |*char| {
        char.* = RawChar{
            .id = try reader.takeInt(u32, .little),
            .x = try reader.takeInt(u16, .little),
            .y = try reader.takeInt(u16, .little),
            .width = try reader.takeInt(u16, .little),
            .height = try reader.takeInt(u16, .little),
            .xOffset = try reader.takeInt(i16, .little),
            .yOffset = try reader.takeInt(i16, .little),
            .xAdvance = try reader.takeInt(i16, .little),
            .page = try reader.takeByte(),
            .chnl = try reader.takeByte(),
        };
    }
    rawFont.chars = chars;
}

fn parseKerningPairs(reader: *std.Io.Reader, size: usize) !void {
    const pairs: usize = @intCast(@divExact(size, 10));

    const kerningPairs = try arena.alloc(KerningPair, pairs);
    for (kerningPairs) |*pair| {
        pair.* = KerningPair{
            .first = try reader.takeInt(u32, .little),
            .second = try reader.takeInt(u32, .little),
            .amount = try reader.takeInt(i16, .little),
        };
    }
    rawFont.kerningPairs = kerningPairs;
}

fn readString(reader: *std.Io.Reader) ![]const u8 {
    return try reader.takeSentinel(0);
}

fn sortChars(chars: []Char) void {
    std.mem.sortUnstable(Char, chars, {}, struct {
        fn lessThan(_: void, a: Char, b: Char) bool {
            return a.id < b.id;
        }
    }.lessThan);
}

fn writeZon(io: std.Io, name: []const u8, value: Font) !void {
    const file = try std.Io.Dir.cwd().createFile(io, name, .{});
    defer file.close(io);

    var buffer: [4096]u8 = undefined;
    var writer = file.writer(io, &buffer);
    try std.zon.stringify.serialize(value, .{}, &writer.interface);
    try writer.interface.flush();
}

const Vec2 = struct { x: f32, y: f32 };
const Rect = struct { min: Vec2, size: Vec2 };

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

pub const RawFont = struct {
    info: Info,
    common: Common,
    pages: []const []const u8,
    chars: []const RawChar,
    kerningPairs: []const KerningPair,
};

pub const Info = struct {
    fontSize: i16,
    bitField: u8,
    charSet: u8,
    stretchH: u16,
    aa: u8,
    paddingUp: u8,
    paddingRight: u8,
    paddingDown: u8,
    paddingLeft: u8,
    spacingHoriz: u8,
    spacingVert: u8,
    outline: u8,
    name: []const u8 = &.{},
};

pub const Common = struct {
    lineHeight: u16,
    base: u16,
    scaleW: u16,
    scaleH: u16,
    pages: u16,
    bitField: u8,
    alphaChnl: u8,
    redChnl: u8,
    greenChnl: u8,
    blueChnl: u8,
};

pub const RawChar = struct {
    id: u32,
    x: u16,
    y: u16,
    width: u16,
    height: u16,
    xOffset: i16,
    yOffset: i16,
    xAdvance: i16,
    page: u8,
    chnl: u8,
};

pub const KerningPair = struct { first: u32, second: u32, amount: i16 };
