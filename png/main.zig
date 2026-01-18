const std = @import("std");
const PNG = @import("png.zig").PNG;

const raw = @embedFile("pointer_c_shaded.png");
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
    width: u32 align(1),
    height: u32 align(1),
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

    while (chunk.chunkEnum != .IEND) {
        chunk = try readChunk(&reader);
        switch (chunk.chunkEnum) {
            .IDAT => try parseData(allocator, header, chunk),
            else => {},
        }
    }
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

fn parseData(allocator: std.mem.Allocator, header: Header, chunk: Chunk) !void {
    var reader = std.Io.Reader.fixed(chunk.data);
    var decompress = std.compress.flate.Decompress.init(&reader, .zlib, &.{});

    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();

    const len = try decompress.reader.streamRemaining(&aw.writer);
    std.log.info("decompress len: {}", .{len});
    reader = std.Io.Reader.fixed(aw.written());

    const capacity = header.width * header.height * 4;
    var imageData = try allocator.alloc(u8, capacity);
    defer allocator.free(imageData);

    var index: usize = 0;
    var previous: []u8 = &.{};
    for (0..header.height) |_| {
        const filterEnum = try reader.takeEnum(FilterEnum, .big);
        std.log.info("filter: {}", .{filterEnum});
        const current = try reader.take(4 * header.width);
        switch (filterEnum) {
            .none => {},
            .sub => {
                const left = current[0 .. current.len - 4];
                for (current[4..], left) |*c, l| c.* +%= l;
            },
            .up => {
                for (current, previous) |*c, p| c.* +%= p;
            },
            .average => {
                // 手动算第一个像素
                current[0] +%= previous[0] / 2;
                current[1] +%= previous[1] / 2;
                current[2] +%= previous[2] / 2;
                current[3] +%= previous[3] / 2;

                const left = current[0 .. current.len - 4];
                for (current[4..], left, previous[4..]) |*c, l, p|
                    c.* +%= ((l + p) / 2);
            },
            .paeth => {
                // 手动算第一个像素
                current[0] = paeth(0, previous[0], 0);
                current[1] = paeth(0, previous[1], 0);
                current[2] = paeth(0, previous[2], 0);
                current[3] = paeth(0, previous[3], 0);

                const left = current[0 .. current.len - 4];
                const previousLeft = previous[0 .. previous.len - 4];

                for (current[4..], left, previous[4..], previousLeft) |*c, l, p, pl|
                    c.* +%= paeth(l, p, pl);
            },
        }
        @memcpy(imageData[index..][0..current.len], current);
        index += current.len;
        previous = current;
    }

    const image = Image.init(header.width, header.height, imageData);
    try image.write("my.ppm");
}

fn paeth(a: u8, b: u8, c: u8) u8 {
    const p = @as(i10, a) + b - c;
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
