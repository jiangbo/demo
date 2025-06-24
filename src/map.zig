const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;
const math = @import("zhu").math;

var texture: gfx.Texture = undefined;
var rowTiles: usize = 0;

const Map = struct {
    width: u16,
    height: u16,
    ground1: []const u16,
    ground2: []const u16,
    object: []const u16,
};

const maps: []const Map = @import("zon/map.zon");
var map: Map = undefined;

var vertexBuffer: [1300]camera.Vertex = undefined;
var vertexIndex: usize = 0;

var objectOffset: usize = 0;
var objectArray: [884]u16 = undefined;

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/maps.png", .init(640, 1536));
    rowTiles = @intFromFloat(@divExact(texture.size().x, 32));
}

pub fn enter(mapId: u16) void {
    map = maps[mapId];
    vertexIndex = 0;

    buildVertexBuffer(map.ground1);
    buildVertexBuffer(map.ground2);
    objectOffset = vertexIndex;

    @memcpy(objectArray[0..map.object.len], map.object);
    buildObjectBuffer();
}

fn buildVertexBuffer(tiles: []const u16) void {
    for (tiles, 0..) |tileIndex, index| {
        if (tileIndex != 0) appendVertex(tileIndex, index);
    }
}

fn buildObjectBuffer() void {
    vertexIndex = objectOffset;
    for (objectArray[0..map.object.len], 0..) |tileIndex, index| {
        switch (tileIndex) {
            0xFF...0xFFF => appendVertex(tileIndex, index),
            0x1000...0x1FFF => appendVertex(301, index),
            else => {},
        }
    }
}

fn appendVertex(tileIndex: usize, index: usize) void {
    const tile = texture.subTexture(getAreaFromIndex(tileIndex));

    vertexBuffer[vertexIndex] = .{
        .position = getPositionFromIndex(index),
        .size = .init(32, 32),
        .texture = tile.area.toVector4(),
    };
    vertexIndex += 1;
}

fn getAreaFromIndex(index: usize) gfx.Rectangle {
    const row: f32 = @floatFromInt(index / rowTiles);
    const col: f32 = @floatFromInt(index % rowTiles);
    return .init(.init(col * 32, row * 32), .init(32, 32));
}

fn getPositionFromIndex(index: usize) gfx.Vector {
    const row: f32 = @floatFromInt(index / map.width);
    const col: f32 = @floatFromInt(index % map.width);
    return math.Vector.init(col * 32, row * 32);
}

pub fn talk(position: gfx.Vector, direction: math.FourDirection) u16 {
    const index: i32 = @intCast(positionIndex(position));
    const talkIndex: i32 = switch (direction) {
        .down => index + map.width,
        .left => index - 1,
        .right => index + 1,
        .up => index - map.width,
    };

    if (talkIndex < 0 or talkIndex > map.object.len) return 0;
    const talkObject = objectArray[@intCast(talkIndex)];
    if (talkObject == 0 or talkObject == 1) return 0;

    changeObjectIfNeed(@intCast(talkIndex), talkObject);
    return talkObject;
}

fn changeObjectIfNeed(index: usize, object: u16) void {
    objectArray[index] = switch (object) {
        0x1000...0x1FFF => 302,
        else => return,
    };
    buildObjectBuffer();
}

pub fn positionIndex(position: gfx.Vector) usize {
    const x: u16 = @intFromFloat(@floor(position.x / 32));
    const y: u16 = @intFromFloat(@floor(position.y / 32));
    return x + y * map.width;
}

pub fn tileCenterContains(position: gfx.Vector) bool {
    const pos = getPositionFromIndex(positionIndex(position));
    const area = gfx.Rectangle.init(pos.addXY(0, 16), .init(32, 16));
    return area.contains(position);
}

pub fn size() gfx.Vector {
    const x: f32 = @floatFromInt(map.width * 32);
    const y: f32 = @floatFromInt(map.height * 32);
    return .init(x, y);
}

pub fn getObject(index: usize) u16 {
    return objectArray[index];
}

pub fn canWalk(position: gfx.Vector) bool {
    if (position.x < 0 or position.y < 0) return false;

    const index = positionIndex(position);
    if (index > map.object.len) return false;
    // 场景切换的图块也应该能通过
    return objectArray[index] == 0 or objectArray[index] > 0x1FFF;
}

pub fn render() void {
    camera.drawVertices(texture, vertexBuffer[0..vertexIndex]);
}
