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
};

const Filter = enum(u8) {
    none = 0,
    sub = 1,
    up = 2,
    average = 3,
    paeth = 4,
};

const Header = struct {
    width: u32,
    height: u32,
    bitDepth: u8,
    color: Color,
    compression: u8,
    filter: u8,
    interlace: u8,
};

const ChunkData = struct { kind: Chunk, data: []const u8 };

pub const Image = struct {
    width: i32,
    height: i32,
    data: []u8,

    pub fn deinit(self: Image, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

pub fn load(allocator: std.mem.Allocator, bytes: []const u8) !Image {
    if (bytes.len < signature.len or
        !std.mem.eql(u8, bytes[0..signature.len], &signature))
    {
        return error.InvalidSignature;
    }

    var pos: usize = signature.len;
    const first = try readChunk(bytes, &pos);
    if (first.kind != .IHDR) return error.InvalidHeader;
    const header = try readHeader(first.data);
    try checkHeader(header);

    var compressed: std.ArrayList(u8) = .empty;
    defer compressed.deinit(allocator);

    var rgbPalette: []const u8 = &.{};
    var alphaPalette: []const u8 = &.{};

    while (true) {
        const chunk = try readChunk(bytes, &pos);
        switch (chunk.kind) {
            .IDAT => try compressed.appendSlice(allocator, chunk.data),
            .PLTE => rgbPalette = chunk.data,
            .tRNS => alphaPalette = chunk.data,
            .IEND => break,
            else => {},
        }
    }

    const width: usize = @intCast(header.width);
    const height: usize = @intCast(header.height);
    const data = try allocator.alloc(u8, width * height * 4);
    errdefer allocator.free(data);

    switch (header.color) {
        .rgba => try parseRgba(data, header, compressed.items),
        .indexed => {
            const palette = try makePalette(allocator, rgbPalette, alphaPalette);
            defer allocator.free(palette);
            try parseIndexed(allocator, data, header, compressed.items, palette);
        },
        else => return error.UnsupportedColor,
    }

    return .{
        .width = @intCast(header.width),
        .height = @intCast(header.height),
        .data = data,
    };
}

fn readHeader(data: []const u8) !Header {
    if (data.len != 13) return error.InvalidHeader;
    return .{
        .width = std.mem.readInt(u32, data[0..4], .big),
        .height = std.mem.readInt(u32, data[4..8], .big),
        .bitDepth = data[8],
        .color = @enumFromInt(data[9]),
        .compression = data[10],
        .filter = data[11],
        .interlace = data[12],
    };
}

fn checkHeader(header: Header) !void {
    if (header.width == 0 or header.height == 0) return error.InvalidHeader;
    if (header.bitDepth != 8) return error.UnsupportedBitDepth;
    if (header.compression != 0) return error.UnsupportedCompression;
    if (header.filter != 0) return error.UnsupportedFilter;
    if (header.interlace != 0) return error.UnsupportedInterlace;
}

fn readChunk(bytes: []const u8, pos: *usize) !ChunkData {
    if (pos.* + 12 > bytes.len) return error.InvalidChunk;

    const len = std.mem.readInt(u32, bytes[pos.*..][0..4], .big);
    const dataLen: usize = @intCast(len);
    const kindStart = pos.* + 4;
    const dataStart = kindStart + 4;
    const dataEnd = dataStart + dataLen;
    const crcEnd = dataEnd + 4;
    if (crcEnd > bytes.len) return error.InvalidChunk;

    const kindInt = std.mem.readInt(u32, bytes[kindStart..][0..4], .big);
    const kind: Chunk = @enumFromInt(kindInt);
    const crc = std.mem.readInt(u32, bytes[dataEnd..][0..4], .big);
    if (crc != std.hash.Crc32.hash(bytes[kindStart..dataEnd])) {
        return error.InvalidCrc;
    }

    pos.* = crcEnd;
    return .{ .kind = kind, .data = bytes[dataStart..dataEnd] };
}

fn makePalette(
    allocator: std.mem.Allocator,
    rgb: []const u8,
    alpha: []const u8,
) ![]u8 {
    if (rgb.len == 0 or rgb.len % 3 != 0) return error.InvalidPalette;

    const result = try allocator.alloc(u8, rgb.len / 3 * 4);
    for (0..result.len / 4) |i| {
        result[i * 4 + 0] = rgb[i * 3 + 0];
        result[i * 4 + 1] = rgb[i * 3 + 1];
        result[i * 4 + 2] = rgb[i * 3 + 2];
        result[i * 4 + 3] = if (i < alpha.len) alpha[i] else 255;
    }
    return result;
}

fn parseIndexed(
    allocator: std.mem.Allocator,
    data: []u8,
    header: Header,
    compressed: []const u8,
    palette: []const u8,
) !void {
    var reader = std.Io.Reader.fixed(compressed);
    var flateBuffer: [std.compress.flate.max_window_len]u8 = undefined;
    var flate = std.compress.flate.Decompress.init(
        &reader,
        .zlib,
        &flateBuffer,
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
        const current = try flate.reader.take(width);
        unfilter(row, current, prior, 1, filter);

        const dest = data[y * width * 4 ..][0 .. width * 4];
        for (row, 0..) |index, x| {
            const color = @as(usize, index) * 4;
            if (color + 4 > palette.len) return error.InvalidPaletteIndex;
            @memcpy(dest[x * 4 ..][0..4], palette[color..][0..4]);
        }

        @memcpy(prior, row);
    }
}

fn parseRgba(data: []u8, header: Header, compressed: []const u8) !void {
    var reader = std.Io.Reader.fixed(compressed);
    var flateBuffer: [std.compress.flate.max_window_len]u8 = undefined;
    var flate = std.compress.flate.Decompress.init(
        &reader,
        .zlib,
        &flateBuffer,
    );

    const width: usize = @intCast(header.width);
    const height: usize = @intCast(header.height);
    const lineLen = width * 4;

    for (0..height) |y| {
        const filter = try flate.reader.takeEnum(Filter, .big);
        const current = try flate.reader.take(lineLen);
        const dest = data[y * lineLen ..][0..lineLen];
        const prior = if (y == 0) &.{} else data[(y - 1) * lineLen ..][0..lineLen];
        unfilter(dest, current, prior, 4, filter);
    }
}

fn unfilter(
    dest: []u8,
    current: []const u8,
    prior: []const u8,
    pixelSize: usize,
    filter: Filter,
) void {
    switch (filter) {
        .none => @memcpy(dest, current),
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
