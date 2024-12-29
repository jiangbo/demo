const std = @import("std");
const objects = @import("objects.zig");

const MAX_BUFFER = 255;

pub fn readMapFile(allocator: std.mem.Allocator, name: []const u8) objects.JsonMap {
    const data = std.fs.cwd().readFileAlloc(allocator, name, std.math.maxInt(u32)) //
    catch unreachable;
    defer allocator.free(data);

    return std.json.parseFromSlice(objects.Map, allocator, data, .{
        .allocate = .alloc_always,
    }) catch unreachable;
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

    objects.persons.resize(count) catch unreachable;
    for (objects.persons.slice()) |*person| {
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
