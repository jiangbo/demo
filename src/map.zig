const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;

var texture: gfx.Texture = undefined;

const Map = struct {
    width: u16,
    height: u16,
    ground: []const u16,
    prop: []const u16,
    object: []const u16,
};

const map: Map = @import("zon/map.zon");

var vertexBuffer: [500]camera.Vertex = undefined;
var vertexIndex: usize = 0;

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/maps.png", .init(640, 1536));

    buildVertexBuffer(map.ground);
    buildVertexBuffer(map.prop);
}

fn buildVertexBuffer(tiles: []const u16) void {
    for (tiles, 0..) |tileIndex, index| {
        const x: u32 = 4;
        const y: u32 = 4;
        if (index == x + y * 20) {
            std.log.info("index: {}, tileIndex: {}", .{ index, tileIndex });
        }

        if (tileIndex == 0) continue;

        const tile = texture.subTexture(getAreaFromIndex(tileIndex));
        vertexBuffer[vertexIndex] = .{
            .position = getAreaFromIndex(index).min,
            .size = .init(32, 32),
            .texture = tile.area.toVector4(),
        };
        vertexIndex += 1;
    }
}

fn getAreaFromIndex(index: usize) gfx.Rectangle {
    const row: f32 = @floatFromInt(index / 20);
    const col: f32 = @floatFromInt(index % 20);
    return .init(.init(col * 32, row * 32), .init(32, 32));
}

pub fn canWalk(position: gfx.Vector) bool {
    const x = @floor(position.x / 32);
    const y = @floor(position.y / 32);

    const index: usize = @intFromFloat(x + y * map.width);
    if (index > map.object.len) return false;
    return map.object[index] == 0;
}

pub fn render() void {
    camera.drawVertex(texture, vertexBuffer[0..vertexIndex]);
}
