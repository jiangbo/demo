const std = @import("std");

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

const Filter = enum(u8) {
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

const IdatInput = struct {
    bytes: []const u8,
    ranges: []const Range,
};

const IdatReader = struct {
    reader: std.Io.Reader,
    bytes: []const u8,
    ranges: []const Range,
    rangeIndex: usize,
    pos: usize,

    const vtable: std.Io.Reader.VTable = .{ .stream = stream };

    // zlib 看到连续数据，底层仍然直接读取原 PNG 的 IDAT 范围。
    fn init(bytes: []const u8, ranges: []const Range, buffer: []u8) IdatReader {
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

    fn stream(
        reader: *std.Io.Reader,
        writer: *std.Io.Writer,
        limit: std.Io.Limit,
    ) std.Io.Reader.StreamError!usize {
        const self: *IdatReader = @alignCast(@fieldParentPtr("reader", reader));
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
            const n = writer.write(data) catch return error.WriteFailed;
            self.pos += n;
            return n;
        }

        return error.EndOfStream;
    }
};

pub const Image = struct {
    width: i32,
    height: i32,
    data: []u8,

    pub fn deinit(self: Image, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

pub fn load(allocator: std.mem.Allocator, file: std.ArrayList(u8)) !Image {
    const bytes = file.items;

    if (bytes.len < signature.len or
        !std.mem.eql(u8, bytes[0..signature.len], &signature))
    {
        return error.InvalidSignature;
    }

    var pos: usize = signature.len;
    const first = try readChunk(bytes, &pos);
    if (first.kind != .IHDR) return error.InvalidHeader;
    if (first.data.len != headerLen) return error.InvalidHeader;
    var header = std.mem.bytesToValue(Header, first.data);
    std.mem.byteSwapAllFields(Header, &header);
    try checkHeader(header);

    var idatRanges: std.ArrayList(Range) = .empty;
    defer idatRanges.deinit(allocator);

    var rgbPalette: []const u8 = &.{};
    var alphaPalette: []const u8 = &.{};

    while (true) {
        const chunk = try readChunk(bytes, &pos);
        switch (chunk.kind) {
            .IDAT => try idatRanges.append(allocator, chunk.range),
            .PLTE => rgbPalette = chunk.data,
            .tRNS => alphaPalette = chunk.data,
            .IEND => break,
            else => {},
        }
    }
    if (idatRanges.items.len == 0) return error.MissingImageData;

    const width: usize = @intCast(header.width);
    const height: usize = @intCast(header.height);
    const count = std.math.mul(usize, width, height) catch {
        return error.ImageTooLarge;
    };
    const dataLen = std.math.mul(usize, count, 4) catch {
        return error.ImageTooLarge;
    };
    const data = try allocator.alloc(u8, dataLen);
    errdefer allocator.free(data);

    // TODO Zig 0.17：改用 std.heap.BufferFirstAllocator。
    // 0.16 还没有这个类型，先复用 stackFallback 的内部固定分配器。
    var tempState = std.heap.stackFallback(1, allocator);
    const tempAllocator = tempState.get();
    // 临时内存优先复用 file 预留空间，不够再走 allocator。
    tempState.fixed_buffer_allocator = .init(file.unusedCapacitySlice());

    const input: IdatInput = .{ .bytes = bytes, .ranges = idatRanges.items };
    switch (header.color) {
        .rgb => try parseRgb(tempAllocator, data, header, input),
        .rgba => try parseRgba(tempAllocator, data, header, input),
        .indexed => {
            const palette = try makePalette(allocator, .{
                .data = rgbPalette,
                .alpha = alphaPalette,
                .rgba = false,
            });
            defer allocator.free(palette);
            try parseIndexed(tempAllocator, data, header, input, palette);
        },
        .magic => {
            const palette = try makePalette(allocator, .{
                .data = rgbPalette,
                .alpha = alphaPalette,
                .rgba = true,
            });
            defer allocator.free(palette);
            try parseIndexed(tempAllocator, data, header, input, palette);
        },
        else => return error.UnsupportedColor,
    }

    return .{
        .width = @intCast(header.width),
        .height = @intCast(header.height),
        .data = data,
    };
}

fn checkHeader(header: Header) !void {
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
}

fn readChunk(bytes: []const u8, pos: *usize) !ChunkData {
    if (pos.* > bytes.len or bytes.len - pos.* < 12) {
        return error.InvalidChunk;
    }

    const len = std.mem.readInt(u32, bytes[pos.*..][0..4], .big);
    const dataLen: usize = @intCast(len);
    const kindStart = pos.* + 4;
    const dataStart = kindStart + 4;
    const dataEnd = std.math.add(usize, dataStart, dataLen) catch {
        return error.InvalidChunk;
    };
    const crcEnd = std.math.add(usize, dataEnd, 4) catch {
        return error.InvalidChunk;
    };
    if (crcEnd > bytes.len) return error.InvalidChunk;

    const kindInt = std.mem.readInt(u32, bytes[kindStart..][0..4], .big);
    const kind: Chunk = @enumFromInt(kindInt);
    const crc = std.mem.readInt(u32, bytes[dataEnd..][0..4], .big);
    if (crc != std.hash.Crc32.hash(bytes[kindStart..dataEnd])) {
        return error.InvalidCrc;
    }

    pos.* = crcEnd;
    return .{
        .kind = kind,
        .data = bytes[dataStart..dataEnd],
        .range = .{ .start = dataStart, .end = dataEnd },
    };
}

const PaletteSource = struct {
    data: []const u8,
    alpha: []const u8,
    rgba: bool,
};

fn makePalette(allocator: std.mem.Allocator, source: PaletteSource) ![]u8 {
    if (source.rgba) {
        if (source.data.len == 0 or source.data.len % 4 != 0) {
            return error.InvalidPalette;
        }
        if (source.data.len / 4 > 256) return error.InvalidPalette;
        if (source.alpha.len != 0) return error.InvalidPalette;
        return allocator.dupe(u8, source.data);
    }

    if (source.data.len == 0 or source.data.len % 3 != 0) {
        return error.InvalidPalette;
    }
    const colorCount = source.data.len / 3;
    if (colorCount > 256) return error.InvalidPalette;
    if (source.alpha.len > colorCount) return error.InvalidPalette;

    const result = try allocator.alloc(u8, colorCount * 4);
    for (0..colorCount) |i| {
        result[i * 4 + 0] = source.data[i * 3 + 0];
        result[i * 4 + 1] = source.data[i * 3 + 1];
        result[i * 4 + 2] = source.data[i * 3 + 2];
        result[i * 4 + 3] = if (i < source.alpha.len) source.alpha[i] else 255;
    }
    return result;
}

fn parseIndexed(
    allocator: std.mem.Allocator,
    data: []u8,
    header: Header,
    input: IdatInput,
    palette: []const u8,
) !void {
    const idatBuffer = try allocator.alloc(u8, idatBufferLen);
    defer allocator.free(idatBuffer);
    var idat = IdatReader.init(input.bytes, input.ranges, idatBuffer);

    const flateBuffer = try allocator.alloc(
        u8,
        std.compress.flate.max_window_len,
    );
    defer allocator.free(flateBuffer);
    var flate = std.compress.flate.Decompress.init(
        &idat.reader,
        .zlib,
        flateBuffer,
    );

    const width: usize = @intCast(header.width);
    const height: usize = @intCast(header.height);
    const row = try allocator.alloc(u8, width);
    defer allocator.free(row);
    const prior = try allocator.alloc(u8, width);
    defer allocator.free(prior);
    @memset(prior, 0);

    for (0..height) |y| {
        const filter = try flate.reader.takeEnum(Filter, .big);
        try flate.reader.readSliceAll(row);
        unfilter(row, row, prior, 1, filter);

        const dest = data[y * width * 4 ..][0 .. width * 4];
        for (row, 0..) |index, x| {
            const color = @as(usize, index) * 4;
            if (color + 4 > palette.len) return error.InvalidPaletteIndex;
            @memcpy(dest[x * 4 ..][0..4], palette[color..][0..4]);
        }

        @memcpy(prior, row);
    }
    try finishFlate(&flate);
}

fn parseRgb(
    allocator: std.mem.Allocator,
    data: []u8,
    header: Header,
    input: IdatInput,
) !void {
    const idatBuffer = try allocator.alloc(u8, idatBufferLen);
    defer allocator.free(idatBuffer);
    var idat = IdatReader.init(input.bytes, input.ranges, idatBuffer);

    const flateBuffer = try allocator.alloc(
        u8,
        std.compress.flate.max_window_len,
    );
    defer allocator.free(flateBuffer);
    var flate = std.compress.flate.Decompress.init(
        &idat.reader,
        .zlib,
        flateBuffer,
    );

    const width: usize = @intCast(header.width);
    const height: usize = @intCast(header.height);
    const lineLen = std.math.mul(usize, width, 3) catch {
        return error.ImageTooLarge;
    };

    const row = try allocator.alloc(u8, lineLen);
    defer allocator.free(row);
    const prior = try allocator.alloc(u8, lineLen);
    defer allocator.free(prior);
    @memset(prior, 0);

    for (0..height) |y| {
        const filter = try flate.reader.takeEnum(Filter, .big);
        try flate.reader.readSliceAll(row);
        unfilter(row, row, prior, 3, filter);

        const dest = data[y * width * 4 ..][0 .. width * 4];
        for (0..width) |x| {
            dest[x * 4 + 0] = row[x * 3 + 0];
            dest[x * 4 + 1] = row[x * 3 + 1];
            dest[x * 4 + 2] = row[x * 3 + 2];
            dest[x * 4 + 3] = 255;
        }

        @memcpy(prior, row);
    }
    try finishFlate(&flate);
}

fn parseRgba(
    allocator: std.mem.Allocator,
    data: []u8,
    header: Header,
    input: IdatInput,
) !void {
    const idatBuffer = try allocator.alloc(u8, idatBufferLen);
    defer allocator.free(idatBuffer);
    var idat = IdatReader.init(input.bytes, input.ranges, idatBuffer);

    const flateBuffer = try allocator.alloc(
        u8,
        std.compress.flate.max_window_len,
    );
    defer allocator.free(flateBuffer);
    var flate = std.compress.flate.Decompress.init(
        &idat.reader,
        .zlib,
        flateBuffer,
    );

    const width: usize = @intCast(header.width);
    const height: usize = @intCast(header.height);
    const lineLen = width * 4;

    for (0..height) |y| {
        const filter = try flate.reader.takeEnum(Filter, .big);
        const dest = data[y * lineLen ..][0..lineLen];
        const prior = if (y == 0)
            &.{}
        else
            data[(y - 1) * lineLen ..][0..lineLen];
        try flate.reader.readSliceAll(dest);
        unfilter(dest, dest, prior, 4, filter);
    }
    try finishFlate(&flate);
}

fn unfilter(
    dest: []u8,
    current: []const u8,
    prior: []const u8,
    pixelSize: usize,
    filter: Filter,
) void {
    switch (filter) {
        .none => {
            if (dest.ptr != current.ptr) @memcpy(dest, current);
        },
        .sub => {
            for (current, 0..) |value, i| {
                const left = if (i >= pixelSize) dest[i - pixelSize] else 0;
                dest[i] = value +% left;
            }
        },
        .up => {
            for (current, 0..) |value, i| {
                const up = if (prior.len == 0) 0 else prior[i];
                dest[i] = value +% up;
            }
        },
        .average => {
            for (current, 0..) |value, i| {
                const left = if (i >= pixelSize) dest[i - pixelSize] else 0;
                const up = if (prior.len == 0) 0 else prior[i];
                dest[i] = value +% average(left, up);
            }
        },
        .paeth => {
            for (current, 0..) |value, i| {
                const left = if (i >= pixelSize) dest[i - pixelSize] else 0;
                const up = if (prior.len == 0) 0 else prior[i];
                const upLeft = if (prior.len != 0 and i >= pixelSize)
                    prior[i - pixelSize]
                else
                    0;
                dest[i] = value +% paeth(left, up, upLeft);
            }
        },
    }
}

fn finishFlate(flate: *std.compress.flate.Decompress) !void {
    var extra: [1]u8 = undefined;
    const n = flate.reader.readSliceShort(&extra) catch |err| {
        if (flate.err) |inner| return inner;
        return err;
    };
    if (n != 0) return error.InvalidImageData;
}

fn average(left: u8, up: u8) u8 {
    return @intCast((@as(u16, left) + up) / 2);
}

fn paeth(left: u8, up: u8, upLeft: u8) u8 {
    const a: i16 = left;
    const b: i16 = up;
    const c: i16 = upLeft;
    const p = a + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    if (pa <= pb and pa <= pc) return left;
    if (pb <= pc) return up;
    return upLeft;
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

fn makeTestPng(allocator: std.mem.Allocator, png: TestPng) ![]u8 {
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
    allocator: std.mem.Allocator,
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
    allocator: std.mem.Allocator,
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
    defer image.deinit(allocator);

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
    defer image.deinit(allocator);

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
    defer image.deinit(allocator);

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
    defer image.deinit(allocator);

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
