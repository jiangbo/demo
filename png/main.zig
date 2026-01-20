const std = @import("std");

const raw = @embedFile("atlas.png");
const signature = [8]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

const ChunkEnum = enum(u32) {
    IHDR = std.mem.readInt(u32, "IHDR", .big),
    PLTE = std.mem.readInt(u32, "PLTE", .big),
    tRNS = std.mem.readInt(u32, "tRNS", .big),
    IDAT = std.mem.readInt(u32, "IDAT", .big),
    IEND = std.mem.readInt(u32, "IEND", .big),
    _,
};

const ColorEnum = enum(u8) {
    grayScale = 0,
    trueColor = 2,
    indexed = 3,
    grayScaleAlpha = 4,
    trueColorAlpha = 6,
};

const FilterEnum = enum(u8) {
    none = 0,
    sub = 1,
    up = 2,
    average = 3,
    paeth = 4,
};

const Header = extern struct {
    width: u32,
    height: u32,
    bitDepth: u8,
    colorEnum: ColorEnum,
    compression: u8,
    filter: u8,
    interlace: u8,
};

const Chunk = struct {
    chunkEnum: ChunkEnum,
    data: []u8,
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var reader = std.Io.Reader.fixed(raw);
    if (!std.mem.eql(u8, try reader.take(8), &signature)) {
        return error.InvalidSignature;
    }

    var chunk = try readChunk(&reader);
    var header = std.mem.bytesToValue(Header, chunk.data);
    std.mem.byteSwapAllFields(Header, &header);
    std.log.info("header: {any}", .{header});

    var compressData: std.ArrayList(u8) = .empty;
    defer compressData.deinit(allocator);

    while (chunk.chunkEnum != .IEND) {
        chunk = try readChunk(&reader);
        switch (chunk.chunkEnum) {
            .IDAT => try compressData.appendSlice(allocator, chunk.data),
            else => {},
        }
    }

    const capacity = header.width * header.height * 4;
    const pixelData = try allocator.alloc(u8, capacity);
    defer allocator.free(pixelData);
    try parseData(pixelData, header, compressData.items);

    const image = Image.init(header.width, header.height, pixelData);
    try image.write("my.ppm");
}

fn readChunk(reader: *std.io.Reader) !Chunk {
    const length: u32 = try reader.takeInt(u32, .big);
    const crcBytes = try reader.peek(length + @sizeOf(ChunkEnum));

    const chunkType = try reader.peek(4);
    std.log.info("chunk: {s}", .{chunkType});
    const chunkEnum = try reader.takeEnum(ChunkEnum, .big);
    const data = try reader.take(length);

    const crc = try reader.takeInt(u32, .big);
    if (crc != std.hash.Crc32.hash(crcBytes)) return error.InvalidCrc;

    return .{ .chunkEnum = chunkEnum, .data = data };
}

fn parseData(pixelData: []u8, header: Header, compressData: []u8) !void {
    var reader = std.Io.Reader.fixed(compressData);
    var decompressBuffer: [std.compress.flate.max_window_len]u8 = undefined;
    const Decompress = std.compress.flate.Decompress;
    var decompress = Decompress.init(&reader, .zlib, &decompressBuffer);
    const lineLen = header.width * 4;

    var prior: []u8 = &.{};
    for (0..header.height) |index| {
        const filterEnum = try decompress.reader.takeEnum(FilterEnum, .big);
        std.log.info("filter: {}", .{filterEnum});
        const current = try decompress.reader.take(lineLen);
        const dest = pixelData[index * lineLen ..][0..lineLen];
        switch (filterEnum) {
            .none => @memcpy(dest, current),
            .sub => {
                for (0..4) |i| dest[i] = current[i];
                const left = dest[0 .. dest.len - 4];
                for (current[4..], left, dest[4..]) |c, l, *d| {
                    d.* = c +% l;
                }
            },
            .up => {
                for (current, prior, dest) |c, p, *d| d.* = c +% p;
            },
            .average => {
                // 手动算第一个像素
                for (0..4) |i| dest[i] = current[i] + (prior[i] / 2);

                const left = dest[0 .. dest.len - 4];
                for (current[4..], left, prior[4..], dest[4..]) |c, l, p, *d|
                    d.* = c +% ((l + p) / 2);
            },
            .paeth => {
                // 手动算第一个像素
                for (0..4) |i| dest[i] = current[i] +% paeth(0, prior[i], 0);

                const left = dest[0 .. dest.len - 4];
                const priorLeft = prior[0 .. prior.len - 4];

                for (current[4..], left, prior[4..], priorLeft, dest[4..]) |c, l, p, pl, *d|
                    d.* = c +% paeth(l, p, pl);
            },
        }
        prior = dest;
    }
}

fn paeth(a: u8, b: u8, c: u8) u8 {
    const p = @as(i16, a) + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    if (pa <= pb and pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
}

pub const Image = struct {
    width: usize,
    height: usize,
    data: []u8,
    pub fn init(width: usize, height: usize, data: []u8) Image {
        std.debug.assert(data.len == width * height * 4);
        return Image{ .width = width, .height = height, .data = data };
    }

    pub fn write(self: Image, path: []const u8) !void {
        var file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        var buffer: [1024]u8 = undefined;
        var writer = file.writer(&buffer);

        try writer.interface.print(
            \\P7
            \\WIDTH {}
            \\HEIGHT {}
            \\DEPTH 4
            \\MAXVAL 255
            \\TUPLTYPE RGB_ALPHA
            \\ENDHDR
            \\
        , .{
            self.width,
            self.height,
        });
        try writer.interface.writeAll(self.data);
        try writer.interface.flush();
    }
};
