const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

const item = @import("item.zig");
const npc = @import("npc.zig");

const SIZE = 32;
const TILE_SIZE: math.Vector2 = .init(SIZE, SIZE);

var texture: gfx.Texture = undefined;
var rowTiles: usize = 0;

const Chest = struct { tileIndex: u16, pickupIndex: u16 };

const Map = struct {
    width: u16,
    height: u16,
    back: []const u16,
    ground: []const u16,
    object: []const u16,
    chests: []const Chest = &.{},
    npcs: []const u8 = &.{},
};

const Link = struct { player: gfx.Vector = .zero, mapId: u8 = 0, id: u8 = 0 };
const zon: []const Map = @import("zon/map.zon");
var links: []const Link = @import("zon/change.zon");
pub var linkIndex: u16 = 6;
pub var current: *const Map = undefined;

var vertexBuffer: [1300]camera.Vertex = undefined;
var vertexArray: std.ArrayListUnmanaged(camera.Vertex) = undefined;
var backgroundIndex: usize = undefined;

pub fn init() void {
    vertexArray = .initBuffer(&vertexBuffer);
    texture = gfx.loadTexture("assets/pic/maps.png", .init(640, 1536));
    rowTiles = @intFromFloat(@divExact(texture.size().x, 32));
}

pub fn enter() math.Vector2 {
    const link = links[linkIndex];
    current = &zon[link.mapId];

    vertexArray.clearRetainingCapacity();

    buildVertexBuffer(current.back);
    buildVertexBuffer(current.ground);
    backgroundIndex = vertexArray.items.len;
    for (current.chests) |chest| {
        if (item.picked.isSet(chest.pickupIndex))
            appendVertex(302, chest.tileIndex)
        else
            appendVertex(301, chest.tileIndex);
    }

    return link.player;
}

fn buildVertexBuffer(tiles: []const u16) void {
    for (tiles, 0..) |tileIndex, index| {
        if (tileIndex != 0) appendVertex(tileIndex, index);
    }
}

fn appendVertex(tileIndex: usize, index: usize) void {
    vertexArray.appendAssumeCapacity(buildVertex(tileIndex, index));
}

fn buildVertex(tileIndex: usize, index: usize) camera.Vertex {
    const row: f32 = @floatFromInt(tileIndex / rowTiles);
    const col: f32 = @floatFromInt(tileIndex % rowTiles);
    const pos = math.Vector2.init(col, row).mul(TILE_SIZE);

    const tile = texture.subTexture(.init(pos, TILE_SIZE));
    return camera.Vertex{
        .position = getPositionFromIndex(index).toVector3(0),
        .size = TILE_SIZE,
        .texture = tile.area.toVector4(),
    };
}

fn getPositionFromIndex(index: usize) gfx.Vector {
    const row: f32 = @floatFromInt(index / current.width);
    const col: f32 = @floatFromInt(index % current.width);
    return math.Vector.init(col, row).mul(TILE_SIZE);
}

pub fn openChest(position: gfx.Vector, direction: math.FourDirection) u16 {
    const index: i32 = @intCast(positionIndex(position));
    const talkIndex: i32 = switch (direction) {
        .down => index + current.width,
        .left => index - 1,
        .right => index + 1,
        .up => index - current.width,
    };

    if (talkIndex < 0 or talkIndex > current.object.len) return 0;
    const talkObject = current.object[@intCast(talkIndex)];
    if (talkObject != 2) return 0;

    return openChestIfNeed(@intCast(talkIndex));
}

fn openChestIfNeed(talkIndex: usize) u16 {
    // back 和 ground 已经填充的顶点不需要修改，修改宝箱的顶点

    for (current.chests, 0..) |chest, index| {
        if (talkIndex != chest.tileIndex) continue;

        // 宝箱已经被打开，不需要处理任何东西
        if (item.picked.isSet(chest.pickupIndex)) return 0;

        // 宝箱还没有打开，修改状态
        item.picked.set(chest.pickupIndex);
        const vertex = buildVertex(302, chest.tileIndex);
        vertexArray.items[backgroundIndex + index] = vertex;
        return chest.pickupIndex;
    }
    unreachable;
}

pub fn positionIndex(position: gfx.Vector) usize {
    const x: u16 = @intFromFloat(@floor(position.x / 32));
    const y: u16 = @intFromFloat(@floor(position.y / 32));
    return x + y * current.width;
}

pub fn tileCenterContains(position: gfx.Vector) bool {
    const pos = getPositionFromIndex(positionIndex(position));
    const area = gfx.Rectangle.init(pos.addXY(0, 16), .init(32, 16));
    return area.contains(position);
}

pub fn size() math.Vector2 {
    const x: f32 = @floatFromInt(current.width);
    const y: f32 = @floatFromInt(current.height);
    return math.Vector2.init(x, y).mul(TILE_SIZE);
}

pub fn getObject(index: usize) u16 {
    return current.object[index];
}

pub fn walkTo(area: math.Rectangle, velocity: math.Vector2) math.Vector2 {
    if (velocity.x == 0 and velocity.y == 0) return area.min;

    const target = area.move(velocity);
    var toPosition = target.min;

    if (velocity.x > 0) {
        const topRight = canWalk(.init(target.max.x, target.min.y));
        const bottomRight = canWalk(target.max);

        if (!topRight or !bottomRight) {
            const index = positionIndex(target.max) / current.width;
            toPosition.x = @floatFromInt(index * SIZE);
        }
    } else if (velocity.x < 0) {
        const topLeft = canWalk(target.min);
        const bottomLeft = canWalk(.init(target.min.x, target.max.y));

        if (!topLeft or !bottomLeft) {
            const index = 1 + positionIndex(target.max) / current.width;
            toPosition.x = @floatFromInt(index * SIZE);
        }
    } else if (velocity.y > 0) {
        const bottomLeft = canWalk(.init(target.min.x, target.max.y));
        const bottomRight = canWalk(target.max);

        if (!bottomLeft or !bottomRight) {
            const index = positionIndex(target.max) % current.width;
            toPosition.y = @floatFromInt(index * SIZE);
        }
    } else if (velocity.y < 0) {
        const topLeft = canWalk(target.min);
        const topRight = canWalk(.init(target.max.x, target.min.y));

        if (!topLeft or !topRight) {
            const index = 1 + positionIndex(target.max) % current.width;
            toPosition.y = @floatFromInt(index * SIZE);
        }
    }

    return toPosition;
}

pub fn canWalk(position: math.Vector2) bool {
    if (position.x < 0 or position.y < 0) return false;
    const index = positionIndex(position);
    if (index > current.object.len) return false;
    // 场景切换的图块也应该能通过
    return current.object[index] == 0 or current.object[index] > 4;
}

pub fn draw() void {
    camera.drawVertices(texture, vertexArray.items);
}
