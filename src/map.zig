const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;
const math = @import("zhu").math;

var texture: gfx.Texture = undefined;

const Map = struct {
    width: u16,
    height: u16,
    ground1: []const u16,
    ground2: []const u16,
    object: []const u16,
};

const map: Map = @import("zon/map.zon");

var vertexBuffer: [500]camera.Vertex = undefined;
var vertexIndex: usize = 0;

var objectOffset: usize = 0;
var objectArray: [1000]u16 = undefined;

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/maps.png", .init(640, 1536));

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
        if (tileIndex > 256) appendVertex(tileIndex, index);
    }
}

fn appendVertex(tileIndex: usize, index: usize) void {
    const tile = texture.subTexture(getAreaFromIndex(tileIndex));
    vertexBuffer[vertexIndex] = .{
        .position = getAreaFromIndex(index).min,
        .size = .init(32, 32),
        .texture = tile.area.toVector4(),
    };
    vertexIndex += 1;
}

fn getAreaFromIndex(index: usize) gfx.Rectangle {
    const row: f32 = @floatFromInt(index / map.width);
    const col: f32 = @floatFromInt(index % map.width);
    return .init(.init(col * 32, row * 32), .init(32, 32));
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
        301 => 302,
        else => return,
    };
    buildObjectBuffer();
}

pub fn positionIndex(position: gfx.Vector) usize {
    const x = @floor(position.x / 32);
    const y = @floor(position.y / 32);
    return @intFromFloat(x + y * map.width);
}

pub fn canWalk(position: gfx.Vector) bool {
    const index = positionIndex(position);
    if (index > map.object.len) return false;
    return objectArray[index] == 0;
}

pub fn render() void {
    camera.drawVertex(texture, vertexBuffer[0..vertexIndex]);
}
