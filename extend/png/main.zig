const std = @import("std");

const signature = [8]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

const IHDR = std.mem.readInt(u32, "IHDR", .big);
const PLTE = std.mem.readInt(u32, "PLTE", .big);
const tRNS = std.mem.readInt(u32, "tRNS", .big);
const IDAT = std.mem.readInt(u32, "IDAT", .big);
const IEND = std.mem.readInt(u32, "IEND", .big);

const indexedColor = 3;
const privateIndexedColor = 44;
const maxInputSize = 512 * 1024 * 1024;

const Header = struct {
    width: u32,
    height: u32,
    bitDepth: u8,
    color: u8,
    compression: u8,
    filter: u8,
    interlace: u8,
};

const Chunk = struct {
    kind: u32,
    name: []const u8,
    data: []const u8,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(
        init.minimal.args,
        init.gpa,
    );
    defer args.deinit();

    _ = args.next();
    const inputArg = args.next() orelse return usage();
    const outputArg = args.next() orelse return usage();
    if (args.next() != null) return usage();

    const inputPath = try init.gpa.dupe(u8, inputArg);
    defer init.gpa.free(inputPath);
    const outputPath = try init.gpa.dupe(u8, outputArg);
    defer init.gpa.free(outputPath);

    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        inputPath,
        init.gpa,
        .limited(maxInputSize),
    );
    defer init.gpa.free(input);

    const output = try convertPng(init.gpa, input);
    defer init.gpa.free(output);

    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = outputPath,
        .data = output,
    });

    std.log.info("write {s} size={d}K", .{ outputPath, output.len / 1024 });
}

fn usage() error{InvalidArgs} {
    std.debug.print("usage: out input.png output.png\n", .{});
    return error.InvalidArgs;
}

fn convertPng(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    if (bytes.len < signature.len) return error.InvalidSignature;
    if (!std.mem.eql(u8, bytes[0..signature.len], &signature)) {
        return error.InvalidSignature;
    }

    var pos: usize = signature.len;
    var header: ?Header = null;
    var rgbPalette: []const u8 = &.{};
    var alphaPalette: []const u8 = &.{};
    var seenIend = false;

    var idats: std.ArrayList([]const u8) = .empty;
    defer idats.deinit(allocator);

    while (pos < bytes.len) {
        const chunk = try readChunk(bytes, &pos);
        switch (chunk.kind) {
            IHDR => {
                if (header != null) return error.InvalidHeader;
                header = try readHeader(chunk.data);
                try checkHeader(header.?);
            },
            PLTE => {
                if (rgbPalette.len != 0) return error.InvalidPalette;
                rgbPalette = chunk.data;
            },
            tRNS => {
                if (alphaPalette.len != 0) return error.InvalidPalette;
                alphaPalette = chunk.data;
                std.log.info("merge chunk tRNS size={d}", .{chunk.data.len});
            },
            IDAT => try idats.append(allocator, chunk.data),
            IEND => {
                seenIend = true;
                break;
            },
            else => {
                std.log.info(
                    "drop chunk {s} size={d}",
                    .{ chunk.name, chunk.data.len },
                );
            },
        }
    }

    const sourceHeader = header orelse return error.MissingHeader;
    if (rgbPalette.len == 0) return error.MissingPalette;
    if (idats.items.len == 0) return error.MissingImageData;
    if (!seenIend) return error.MissingEnd;

    var paletteBuffer: [256 * 4]u8 = undefined;
    const rgbaPalette = try makeRgbaPalette(
        &paletteBuffer,
        rgbPalette,
        alphaPalette,
    );

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, &signature);

    var targetHeader = sourceHeader;
    targetHeader.color = privateIndexedColor;
    const headerData = writeHeader(targetHeader);
    try appendChunk(&output, allocator, "IHDR", &headerData);
    try appendChunk(&output, allocator, "PLTE", rgbaPalette);

    for (idats.items) |idat| {
        try appendChunk(&output, allocator, "IDAT", idat);
    }
    try appendChunk(&output, allocator, "IEND", &.{});

    return output.toOwnedSlice(allocator);
}

fn readHeader(data: []const u8) !Header {
    if (data.len != 13) return error.InvalidHeader;
    return .{
        .width = std.mem.readInt(u32, data[0..4], .big),
        .height = std.mem.readInt(u32, data[4..8], .big),
        .bitDepth = data[8],
        .color = data[9],
        .compression = data[10],
        .filter = data[11],
        .interlace = data[12],
    };
}

fn checkHeader(header: Header) !void {
    if (header.width == 0 or header.height == 0) return error.InvalidHeader;
    if (header.bitDepth != 8) return error.UnsupportedBitDepth;
    if (header.color != indexedColor) return error.UnsupportedColor;
    if (header.compression != 0) return error.UnsupportedCompression;
    if (header.filter != 0) return error.UnsupportedFilter;
    if (header.interlace != 0) return error.UnsupportedInterlace;
}

fn writeHeader(header: Header) [13]u8 {
    var data: [13]u8 = undefined;
    std.mem.writeInt(u32, data[0..4], header.width, .big);
    std.mem.writeInt(u32, data[4..8], header.height, .big);
    data[8] = header.bitDepth;
    data[9] = header.color;
    data[10] = header.compression;
    data[11] = header.filter;
    data[12] = header.interlace;
    return data;
}

fn readChunk(bytes: []const u8, pos: *usize) !Chunk {
    if (pos.* > bytes.len or bytes.len - pos.* < 12) {
        return error.InvalidChunk;
    }

    const dataLen: usize = @intCast(std.mem.readInt(
        u32,
        bytes[pos.*..][0..4],
        .big,
    ));
    const kindStart = pos.* + 4;
    const dataStart = kindStart + 4;
    const dataEnd = std.math.add(usize, dataStart, dataLen) catch {
        return error.InvalidChunk;
    };
    const crcEnd = std.math.add(usize, dataEnd, 4) catch {
        return error.InvalidChunk;
    };
    if (crcEnd > bytes.len) return error.InvalidChunk;

    const name = bytes[kindStart..][0..4];
    const data = bytes[dataStart..dataEnd];
    const crc = std.mem.readInt(u32, bytes[dataEnd..][0..4], .big);

    var hash = std.hash.Crc32.init();
    hash.update(name);
    hash.update(data);
    if (hash.final() != crc) return error.InvalidCrc;

    pos.* = crcEnd;
    return .{
        .kind = std.mem.readInt(u32, name, .big),
        .name = name,
        .data = data,
    };
}

fn makeRgbaPalette(
    output: []u8,
    rgb: []const u8,
    alpha: []const u8,
) ![]const u8 {
    if (rgb.len == 0 or rgb.len % 3 != 0) return error.InvalidPalette;
    const colorCount = rgb.len / 3;
    if (colorCount > 256) return error.InvalidPalette;
    if (alpha.len > colorCount) return error.InvalidPalette;

    const len = colorCount * 4;
    if (output.len < len) return error.InvalidPalette;

    for (0..colorCount) |i| {
        output[i * 4 + 0] = rgb[i * 3 + 0];
        output[i * 4 + 1] = rgb[i * 3 + 1];
        output[i * 4 + 2] = rgb[i * 3 + 2];
        output[i * 4 + 3] = if (i < alpha.len) alpha[i] else 255;
    }
    return output[0..len];
}

fn appendChunk(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    name: []const u8,
    data: []const u8,
) !void {
    if (name.len != 4) return error.InvalidChunk;

    var lenBytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &lenBytes, @intCast(data.len), .big);
    try output.appendSlice(allocator, &lenBytes);
    try output.appendSlice(allocator, name);
    try output.appendSlice(allocator, data);

    var hash = std.hash.Crc32.init();
    hash.update(name);
    hash.update(data);

    var crcBytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &crcBytes, hash.final(), .big);
    try output.appendSlice(allocator, &crcBytes);
}

test "convert indexed png to private indexed png" {
    const allocator = std.testing.allocator;

    var input: std.ArrayList(u8) = .empty;
    defer input.deinit(allocator);
    try input.appendSlice(allocator, &signature);

    const header = writeHeader(.{
        .width = 2,
        .height = 1,
        .bitDepth = 8,
        .color = indexedColor,
        .compression = 0,
        .filter = 0,
        .interlace = 0,
    });
    try appendChunk(&input, allocator, "IHDR", &header);
    try appendChunk(&input, allocator, "gAMA", &.{ 0, 0, 0, 1 });
    try appendChunk(&input, allocator, "PLTE", &.{ 10, 20, 30, 40, 50, 60 });
    try appendChunk(&input, allocator, "tRNS", &.{70});
    try appendChunk(&input, allocator, "IDAT", &.{ 1, 2, 3 });
    try appendChunk(&input, allocator, "IEND", &.{});

    const output = try convertPng(allocator, input.items);
    defer allocator.free(output);

    try std.testing.expectEqualSlices(u8, &signature, output[0..8]);

    var pos: usize = signature.len;
    const outHeaderChunk = try readChunk(output, &pos);
    const outHeader = try readHeader(outHeaderChunk.data);
    try std.testing.expectEqual(IHDR, outHeaderChunk.kind);
    try std.testing.expectEqual(privateIndexedColor, outHeader.color);

    const outPalette = try readChunk(output, &pos);
    try std.testing.expectEqual(PLTE, outPalette.kind);
    try std.testing.expectEqualSlices(u8, &.{
        10, 20, 30, 70,
        40, 50, 60, 255,
    }, outPalette.data);

    const outIdat = try readChunk(output, &pos);
    try std.testing.expectEqual(IDAT, outIdat.kind);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3 }, outIdat.data);

    const outEnd = try readChunk(output, &pos);
    try std.testing.expectEqual(IEND, outEnd.kind);
    try std.testing.expectEqual(output.len, pos);
}

test "reject non indexed png" {
    const allocator = std.testing.allocator;

    var input: std.ArrayList(u8) = .empty;
    defer input.deinit(allocator);
    try input.appendSlice(allocator, &signature);

    const header = writeHeader(.{
        .width = 1,
        .height = 1,
        .bitDepth = 8,
        .color = 6,
        .compression = 0,
        .filter = 0,
        .interlace = 0,
    });
    try appendChunk(&input, allocator, "IHDR", &header);
    try appendChunk(&input, allocator, "IDAT", &.{ 1, 2, 3 });
    try appendChunk(&input, allocator, "IEND", &.{});

    try std.testing.expectError(
        error.UnsupportedColor,
        convertPng(allocator, input.items),
    );
}
