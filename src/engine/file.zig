const std = @import("std");

const DIR = "maps";

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
    var reader = buf_reader.reader();

    const readBytes = reader.readUntilDelimiter(&buffer, '\n') catch unreachable;
    const trimBytes = std.mem.trimRight(u8, readBytes, "\r");
    const count = std.fmt.parseInt(u8, trimBytes, 10) catch unreachable;
    std.log.info("read {d} people", .{count});

    // std::ifstream m_peopleFile(m_peopleFileName, std::ios::binary);
    // // Get the number of people in the file.
    // GetStringFromFile(m_peopleFile, buf);
    // m_People.SetPersonCount(atoi(buf));
    // for (int person=0; person<m_People.GetPersonCount(); ++person)
    // {
    // // Get the person’s name.
    // GetStringFromFile(m_peopleFile, buf);
    // m_People.GetPerson(person)->SetName(buf);
    // // Get the person’s location.
    // GetStringFromFile(m_peopleFile, buf);
    // m_People.GetPerson(person)->SetSector(atoi(buf));
    // // Get the person’s move capability.
    // GetStringFromFile(m_peopleFile, buf);
    // if (buf[1] == 'F')
    // m_People.GetPerson(person)->SetCanMove(FALSE);
    // else
    // m_People.GetPerson(person)->SetCanMove(TRUE);
    // // Get the person’s tile number.
    // GetStringFromFile(m_peopleFile, buf);
    // m_People.GetPerson(person)->SetTile(atoi(buf));
    // }
    // m_peopleFile.close();

}
// pub fn readContainerFile(fileName) void {}
// pub fn readDoorFile(fileName) void {}
