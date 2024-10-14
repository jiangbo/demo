const std = @import("std");
const object = @import("object.zig");

const MAX_BUFFER = 255;

pub fn readMapFile(name: []const u8, buffer: []u8) u8 {
    var file = std.fs.cwd().openFile(name, .{}) catch unreachable;
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var reader = buf_reader.reader();
    const mapType = reader.readByte() catch unreachable;
    const size = reader.readAll(buffer) catch unreachable;
    std.log.info("read {s} with type {d} and size {d}", .{ name, mapType, size });

    return mapType;
}
pub fn readPeopleFile(name: []const u8) void {
    var buffer: [MAX_BUFFER]u8 = undefined;
    const path = std.fmt.bufPrint(&buffer, "{s}.peo", .{name}) catch unreachable;

    var file = std.fs.cwd().openFile(path, .{}) catch unreachable;
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    const count = readInt(u8, reader, &buffer);
    std.log.info("read {d} people", .{count});

    object.persons.resize(count) catch unreachable;
    for (object.persons.slice()) |*person| {
        person.name.appendSlice(readLine(reader, &buffer)) catch unreachable;
        person.sector = readInt(u32, reader, &buffer);
        person.canMove = readLine(reader, &buffer)[1] == 'F';
        person.tile = readInt(u32, reader, &buffer);
    }
}
// pub fn readContainerFile(fileName) void {}
// pub fn readDoorFile(fileName) void {}

fn readLine(reader: anytype, buffer: []u8) []const u8 {
    const readBytes = reader.readUntilDelimiter(buffer, '\n');
    return std.mem.trimRight(u8, readBytes catch unreachable, "\r");
}

fn readInt(T: type, reader: anytype, buffer: []u8) T {
    return std.fmt.parseInt(T, readLine(reader, buffer), 10) catch unreachable;
}
