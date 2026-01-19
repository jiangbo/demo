const std = @import("std");

const raw = @embedFile("pointer_c_shaded.png");
// const raw = @embedFile("atlas.png");
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

const Chunk = struct { chunkEnum: ChunkEnum, data: []u8 };

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

    const capacity = header.width * header.height * 4;
    const imageData = try allocator.alloc(u8, capacity);
    defer allocator.free(imageData);

    var compressData: std.ArrayList(u8) = .empty;

    // var index: usize = 0;
    // while (chunk.chunkEnum != .IEND) {
    //     chunk = try readChunk(&reader);
    //     const data = imageData[index..];
    //     switch (chunk.chunkEnum) {
    //         .IDAT => index += try parseData(data, header, chunk),
    //         else => {},
    //     }
    // }
    while (chunk.chunkEnum != .IEND) {
        chunk = try readChunk(&reader);
        switch (chunk.chunkEnum) {
            .IDAT => try compressData.appendSlice(allocator, chunk.data),
            else => {},
        }
    }

    try parseData(imageData, header, compressData.items);

    const image = Image.init(header.width, header.height, imageData);
    try image.write("assets/png.ppm");
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

fn parseData(data: []u8, header: Header, compress: []u8) !void {
    std.log.info("compress len: {}", .{compress.len});
    var reader = std.Io.Reader.fixed(compress);
    const Decompress = std.compress.flate.Decompress;
    var decompress = Decompress.init(&reader, .zlib, &.{});

    // var buffer: [std.compress.flate.max_window_len]u8 = undefined;

    var index: usize = 0;
    var prior: []u8 = &.{};
    for (0..header.height) |_| {
        var buffer: [1024 * 8]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buffer);
        try decompress.reader.streamExact(&writer, 1 + 4 * header.width);

        const filterEnum = try decompress.reader.takeEnum(FilterEnum, .big);
        std.log.info("filter: {}", .{filterEnum});
        const current = try decompress.reader.take(4 * header.width);
        switch (filterEnum) {
            .none => {},
            .sub => {
                const left = current[0 .. current.len - 4];
                for (current[4..], left) |*c, l| c.* +%= l;
            },
            .up => {
                for (current, prior) |*c, p| c.* +%= p;
            },
            .average => {
                // 手动算第一个像素
                for (0..4) |i| current[i] +%= prior[i] / 2;

                const left = current[0 .. current.len - 4];
                for (current[4..], left, prior[4..]) |*c, l, p|
                    c.* +%= ((l + p) / 2);
            },
            .paeth => {
                // 手动算第一个像素
                for (0..4) |i| current[i] +%= paeth(0, prior[i], 0);

                const left = current[0 .. current.len - 4];
                const priorLeft = prior[0 .. prior.len - 4];

                for (current[4..], left, prior[4..], priorLeft) |*c, l, p, pl|
                    c.* +%= paeth(l, p, pl);
            },
        }
        @memcpy(data[index..][0..current.len], current);
        index += current.len;
        prior = current;
    }
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
