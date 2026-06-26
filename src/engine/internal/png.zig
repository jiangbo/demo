const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;
const Limit = std.Io.Limit;
const Decompress = std.compress.flate.Decompress;

const signature = [8]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

const Chunk = enum(u32) {
    IHDR = std.mem.readInt(u32, "IHDR", .big),
    PLTE = std.mem.readInt(u32, "PLTE", .big),
    tRNS = std.mem.readInt(u32, "tRNS", .big),
    IDAT = std.mem.readInt(u32, "IDAT", .big),
    IEND = std.mem.readInt(u32, "IEND", .big),
    _,
};

const Color = enum(u8) {
    gray = 0,
    rgb = 2,
    indexed = 3,
    grayAlpha = 4,
    rgba = 6,
    magic = 44, // 私有扩展：PLTE 是 RGBA 调色板。
};

const Filter = enum(u8) { none, sub, up, average, paeth };

const Header = extern struct {
    width: u32,
    height: u32,
    bitDepth: u8,
    color: Color,
    compression: u8,
    filter: u8,
    interlace: u8,
};

const Range = struct { start: usize, end: usize };
const headerLen = 13;
const idatBufferLen = 4096;

const ChunkData = struct {
    kind: Chunk,
    data: []const u8,
    range: Range,
};

const Decode = struct {
    flate: *Decompress,
    data: []u8,
    header: Header,
    row: []u8,
    prior: []u8,
};

const DataReader = struct {
    reader: Reader,
    bytes: []const u8,
    ranges: []const Range,
    rangeIndex: usize,
    pos: usize,

    const vtable: Reader.VTable = .{ .stream = stream };

    // zlib 看到连续数据，底层仍然直接读取原 PNG 的 IDAT 范围。
    fn init(bytes: []const u8, ranges: []const Range, buffer: []u8) DataReader {
        const pos = if (ranges.len == 0) 0 else ranges[0].start;
        return .{
            .reader = .{
                .vtable = &vtable,
                .buffer = buffer,
                .seek = 0,
                .end = 0,
            },
            .bytes = bytes,
            .ranges = ranges,
            .rangeIndex = 0,
            .pos = pos,
        };
    }

    fn stream(reader: *Reader, writer: *Writer, limit: Limit) !usize {
        const self: *DataReader = @alignCast(@fieldParentPtr("reader", reader));
        if (limit == .nothing) return 0;

        while (self.rangeIndex < self.ranges.len) {
            const range = self.ranges[self.rangeIndex];
            if (self.pos >= range.end) {
                self.rangeIndex += 1;
                if (self.rangeIndex < self.ranges.len) {
                    self.pos = self.ranges[self.rangeIndex].start;
                }
                continue;
            }

            const left = range.end - self.pos;
            const size = limit.minInt(left);
            const data = self.bytes[self.pos..][0..size];
            const n = try writer.write(data);
            self.pos += n;
            return n;
        }

        return error.EndOfStream;
    }
};

pub const Image = struct { width: i32, height: i32, data: []u8 };

pub fn load(allocator: Allocator, file: std.ArrayList(u8)) !Image {
    const bytes = file.items;

    var reader = Reader.fixed(bytes);
    const header = try readHeader(&reader);

    // TODO Zig 0.17：改用 std.heap.BufferFirstAllocator。
    // 0.16 还没有这个类型，先复用 stackFallback 的内部固定分配器。
    var tempState = std.heap.stackFallback(1, allocator);
    const backing = tempState.get();
    // 临时内存优先复用 file 预留空间，不够再走 allocator。
    tempState.fixed_buffer_allocator = .init(file.unusedCapacitySlice());

    var arena = std.heap.ArenaAllocator.init(backing);
    defer arena.deinit();
    const gpa = arena.allocator();

    var ranges: std.ArrayList(Range) = .empty;

    var rgb: []const u8 = &.{};
    var alpha: []const u8 = &.{};

    while (true) {
        const chunk = try readChunk(&reader);
        switch (chunk.kind) {
            .IDAT => try ranges.append(gpa, chunk.range),
            .PLTE => rgb = chunk.data,
            .tRNS => alpha = chunk.data,
            .IEND => break,
            else => {},
        }
    }
    if (ranges.items.len == 0) return error.MissingImageData;

    const len = header.width * header.height * 4;
    const pixelData = try allocator.alloc(u8, len);
    errdefer allocator.free(pixelData);

    const idatBuffer = try gpa.alloc(u8, idatBufferLen);
    var source = DataReader.init(bytes, ranges.items, idatBuffer);

    const prior = try gpa.alloc(u8, header.width * 3);
    @memset(prior, 0);

    const buffer = try gpa.alloc(u8, std.compress.flate.max_window_len);
    var flate = Decompress.init(&source.reader, .zlib, buffer);
    const decode: Decode = .{
        .flate = &flate,
        .data = pixelData,
        .header = header,
        .row = try gpa.alloc(u8, header.width * 3),
        .prior = prior,
    };

    switch (header.color) {
        .rgb => try parseRgb(&decode),
        .rgba => try parseRgba(&decode),
        .indexed => {
            var buf: [256 * 4]u8 = undefined; // 256 色，每色 4 字节。
            for (0..rgb.len / 3) |i| {
                buf[i * 4 + 0] = rgb[i * 3 + 0];
                buf[i * 4 + 1] = rgb[i * 3 + 1];
                buf[i * 4 + 2] = rgb[i * 3 + 2];
                const a = if (i < alpha.len) alpha[i] else 255;
                buf[i * 4 + 3] = a;
            }
            const palette = buf[0 .. rgb.len / 3 * 4];
            try parseIndexed(&decode, palette);
        },
        .magic => try parseIndexed(&decode, rgb),
        else => return error.UnsupportedColor,
    }
    return .{
        .width = @intCast(header.width),
        .height = @intCast(header.height),
        .data = pixelData,
    };
}

fn readHeader(reader: *Reader) !Header {
    const head = try reader.take(signature.len);
    if (!std.mem.eql(u8, head, &signature)) {
        return error.InvalidSignature;
    }

    const first = try readChunk(reader);
    if (first.kind != .IHDR) return error.InvalidHeader;
    if (first.data.len != headerLen) return error.InvalidHeader;

    var header = std.mem.bytesToValue(Header, first.data);
    std.mem.byteSwapAllFields(Header, &header);

    if (header.width == 0 or header.height == 0) return error.InvalidHeader;
    if (header.width > std.math.maxInt(i32)) return error.ImageTooLarge;
    if (header.height > std.math.maxInt(i32)) return error.ImageTooLarge;
    if (header.bitDepth != 8) return error.UnsupportedBitDepth;
    switch (header.color) {
        .rgb, .rgba, .indexed, .magic => {},
        else => return error.UnsupportedColor,
    }
    if (header.compression != 0) return error.UnsupportedCompression;
    if (header.filter != 0) return error.UnsupportedFilter;
    if (header.interlace != 0) return error.UnsupportedInterlace;

    return header;
}

fn readChunk(reader: *Reader) !ChunkData {
    const dataLen = try reader.takeInt(u32, .big);
    const crcBytes = try reader.peek(dataLen + @sizeOf(Chunk));

    const kind = try reader.takeEnum(Chunk, .big);
    const start = reader.seek;
    const data = try reader.take(dataLen);
    const crc = try reader.takeInt(u32, .big);
    if (crc != std.hash.Crc32.hash(crcBytes)) return error.InvalidCrc;

    return .{
        .kind = kind,
        .data = data,
        .range = .{ .start = start, .end = start + data.len },
    };
}

fn parseIndexed(decode: *const Decode, palette: []const u8) !void {
    const width = decode.header.width;
    const row = decode.row[0..width];
    const prior = decode.prior[0..width];

    for (0..decode.header.height) |y| {
        const filter = try decode.flate.reader.takeEnum(Filter, .big);
        try decode.flate.reader.readSliceAll(row);
        unFilter(row, prior, 1, filter);

        const dest = decode.data[y * width * 4 ..][0 .. width * 4];
        for (row, 0..) |index, x| {
            const color = @as(usize, index) * 4;
            if (color + 4 > palette.len) return error.InvalidPaletteIndex;
            @memcpy(dest[x * 4 ..][0..4], palette[color..][0..4]);
        }

        @memcpy(prior, row);
    }
}

fn parseRgb(decode: *const Decode) !void {
    const width = decode.header.width;

    for (0..decode.header.height) |y| {
        const filter = try decode.flate.reader.takeEnum(Filter, .big);
        try decode.flate.reader.readSliceAll(decode.row);
        unFilter(decode.row, decode.prior, 3, filter);

        const dest = decode.data[y * width * 4 ..][0 .. width * 4];
        for (0..width) |x| {
            dest[x * 4 + 0] = decode.row[x * 3 + 0];
            dest[x * 4 + 1] = decode.row[x * 3 + 1];
            dest[x * 4 + 2] = decode.row[x * 3 + 2];
            dest[x * 4 + 3] = 255;
        }

        @memcpy(decode.prior, decode.row);
    }
}

fn parseRgba(decode: *const Decode) !void {
    const len = decode.header.width * 4;
    var pre: []const u8 = &.{};

    for (0..decode.header.height) |y| {
        const filter = try decode.flate.reader.takeEnum(Filter, .big);
        const dest = decode.data[y * len ..][0..len];
        try decode.flate.reader.readSliceAll(dest);
        unFilter(dest, pre, 4, filter);
        pre = dest;
    }
}

fn unFilter(cur: []u8, pre: []const u8, size: usize, f: Filter) void {
    switch (f) {
        .none => {},
        .sub => for (cur, 0..) |*value, i| {
            value.* +%= if (i >= size) cur[i - size] else 0;
        },
        .up => for (cur, 0..) |*value, i| {
            value.* +%= if (pre.len == 0) 0 else pre[i];
        },
        .average => for (cur, 0..) |*value, i| {
            const left = if (i >= size) cur[i - size] else 0;
            const up = if (pre.len == 0) 0 else pre[i];
            value.* +%= @intCast((@as(u16, left) + up) / 2);
        },
        .paeth => for (cur, 0..) |*value, i| {
            const left = if (i >= size) cur[i - size] else 0;
            const up = if (pre.len == 0) 0 else pre[i];
            var upLeft: u8 = 0;
            if (pre.len != 0 and i >= size) upLeft = pre[i - size];
            value.* +%= paeth(left, up, upLeft);
        },
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

const TestPng = struct {
    width: u32,
    height: u32,
    color: u8,
    scanlines: []const u8,
    bitDepth: u8 = 8,
    interlace: u8 = 0,
    plte: []const u8 = &.{},
    trns: []const u8 = &.{},
    splitIdat: bool = false,
};

fn makeTestPng(allocator: Allocator, png: TestPng) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, &signature);

    var ihdr: [13]u8 = undefined;
    std.mem.writeInt(u32, ihdr[0..4], png.width, .big);
    std.mem.writeInt(u32, ihdr[4..8], png.height, .big);
    ihdr[8] = png.bitDepth;
    ihdr[9] = png.color;
    ihdr[10] = 0;
    ihdr[11] = 0;
    ihdr[12] = png.interlace;
    try appendChunk(&result, allocator, "IHDR", &ihdr);

    if (png.plte.len != 0) {
        try appendChunk(&result, allocator, "PLTE", png.plte);
    }
    if (png.trns.len != 0) {
        try appendChunk(&result, allocator, "tRNS", png.trns);
    }

    const zlib = try makeStoredZlib(allocator, png.scanlines);
    defer allocator.free(zlib);
    if (png.splitIdat) {
        const mid = zlib.len / 2;
        try appendChunk(&result, allocator, "IDAT", zlib[0..mid]);
        try appendChunk(&result, allocator, "IDAT", zlib[mid..]);
    } else {
        try appendChunk(&result, allocator, "IDAT", zlib);
    }
    try appendChunk(&result, allocator, "IEND", &.{});

    return result.toOwnedSlice(allocator);
}

fn makeStoredZlib(
    allocator: Allocator,
    data: []const u8,
) ![]u8 {
    if (data.len > std.math.maxInt(u16)) return error.TestDataTooLarge;

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, &.{ 0x78, 0x01, 0x01 });

    var lenBytes: [2]u8 = undefined;
    const len: u16 = @intCast(data.len);
    std.mem.writeInt(u16, &lenBytes, len, .little);
    try result.appendSlice(allocator, &lenBytes);
    std.mem.writeInt(u16, &lenBytes, ~len, .little);
    try result.appendSlice(allocator, &lenBytes);

    try result.appendSlice(allocator, data);

    var adlerBytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &adlerBytes, std.hash.Adler32.hash(data), .big);
    try result.appendSlice(allocator, &adlerBytes);

    return result.toOwnedSlice(allocator);
}

fn appendChunk(
    result: *std.ArrayList(u8),
    allocator: Allocator,
    kind: []const u8,
    data: []const u8,
) !void {
    if (kind.len != 4) return error.InvalidChunk;

    var lenBytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &lenBytes, @intCast(data.len), .big);
    try result.appendSlice(allocator, &lenBytes);
    try result.appendSlice(allocator, kind);
    try result.appendSlice(allocator, data);

    var crc = std.hash.Crc32.init();
    crc.update(kind);
    crc.update(data);

    var crcBytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &crcBytes, crc.final(), .big);
    try result.appendSlice(allocator, &crcBytes);
}

test "load rgba png" {
    const allocator = std.testing.allocator;
    const png = try makeTestPng(allocator, .{
        .width = 2,
        .height = 1,
        .color = 6,
        .scanlines = &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8 },
    });
    defer allocator.free(png);

    const image = try load(allocator, .{ .items = png, .capacity = png.len });
    defer allocator.free(image.data);

    try std.testing.expectEqual(@as(i32, 2), image.width);
    try std.testing.expectEqual(@as(i32, 1), image.height);
    try std.testing.expectEqualSlices(u8, &.{
        1, 2, 3, 4,
        5, 6, 7, 8,
    }, image.data);
}

test "load rgb png" {
    const allocator = std.testing.allocator;
    const png = try makeTestPng(allocator, .{
        .width = 2,
        .height = 1,
        .color = 2,
        .scanlines = &.{ 0, 1, 2, 3, 4, 5, 6 },
    });
    defer allocator.free(png);

    const image = try load(allocator, .{ .items = png, .capacity = png.len });
    defer allocator.free(image.data);

    try std.testing.expectEqualSlices(u8, &.{
        1, 2, 3, 255,
        4, 5, 6, 255,
    }, image.data);
}

test "load indexed png with trns" {
    const allocator = std.testing.allocator;
    const png = try makeTestPng(allocator, .{
        .width = 2,
        .height = 1,
        .color = 3,
        .plte = &.{ 10, 20, 30, 40, 50, 60 },
        .trns = &.{ 70, 80 },
        .scanlines = &.{ 0, 0, 1 },
    });
    defer allocator.free(png);

    const image = try load(allocator, .{ .items = png, .capacity = png.len });
    defer allocator.free(image.data);

    try std.testing.expectEqualSlices(u8, &.{
        10, 20, 30, 70,
        40, 50, 60, 80,
    }, image.data);
}

test "load magic png with rgba palette" {
    const allocator = std.testing.allocator;
    const png = try makeTestPng(allocator, .{
        .width = 2,
        .height = 1,
        .color = 44,
        .plte = &.{ 10, 20, 30, 40, 50, 60, 70, 80 },
        .scanlines = &.{ 0, 0, 1 },
        .splitIdat = true,
    });
    defer allocator.free(png);

    const image = try load(allocator, .{ .items = png, .capacity = png.len });
    defer allocator.free(image.data);

    try std.testing.expectEqualSlices(u8, &.{
        10, 20, 30, 40,
        50, 60, 70, 80,
    }, image.data);
}

test "reject unsupported png header" {
    const allocator = std.testing.allocator;
    const bitDepthPng = try makeTestPng(allocator, .{
        .width = 1,
        .height = 1,
        .color = 6,
        .bitDepth = 16,
        .scanlines = &.{ 0, 1, 2, 3, 4 },
    });
    defer allocator.free(bitDepthPng);
    try std.testing.expectError(
        error.UnsupportedBitDepth,
        load(allocator, .{
            .items = bitDepthPng,
            .capacity = bitDepthPng.len,
        }),
    );

    const interlacePng = try makeTestPng(allocator, .{
        .width = 1,
        .height = 1,
        .color = 6,
        .interlace = 1,
        .scanlines = &.{ 0, 1, 2, 3, 4 },
    });
    defer allocator.free(interlacePng);
    try std.testing.expectError(
        error.UnsupportedInterlace,
        load(allocator, .{
            .items = interlacePng,
            .capacity = interlacePng.len,
        }),
    );
}
