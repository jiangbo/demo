const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;
const tiled = zhu.extend.tiled;
const Vector2 = zhu.Vector2;

const level: tiled.Map = @import("zon/level1.zon");
var tileVertexes: std.ArrayList(batch.Vertex) = .empty;
var tiles: std.ArrayList(tiled.Tile) = .empty;

pub var playerStart: zhu.Vector2 = .zero;

pub fn init() void {
    for (level.layers) |layer| {
        if (layer.type == .tile) parseTileLayer(&layer) //
        else if (layer.type == .object) parseObjectLayer(&layer);
    }
}

pub fn deinit() void {
    tiles.deinit(zhu.assets.allocator);
    tileVertexes.deinit(zhu.assets.allocator);
}

fn parseTileLayer(layer: *const tiled.Layer) void {
    var firstImage = zhu.assets.getImage(level.tileSets[0].images[0]);
    for (layer.data, 0..) |tileIndex, index| {
        if (tileIndex == 0) continue;

        const tileSet = blk: for (level.tileSets) |tileSet| {
            if (tileIndex < tileSet.max) break :blk tileSet;
        } else unreachable;

        const x: f32 = @floatFromInt(index % level.width);
        const y: f32 = @floatFromInt(index / level.width);
        var pos = level.tileSize.mul(.xy(x, y));

        var image: zhu.graphics.Image = undefined;
        const id = tileIndex - tileSet.min;
        const columns = tileSet.columns; // 单图片瓦片集的列数
        if (columns == 0) {
            image = zhu.assets.getImage(tileSet.images[id]);
            pos.y = pos.y - image.area.size.y + level.tileSize.y;
        } else {
            const area = tiled.tileArea(id, level.tileSize, columns);
            image = firstImage.sub(area);
        }

        tileVertexes.append(zhu.assets.allocator, .{
            .position = pos,
            .size = image.area.size,
            .texturePosition = image.area.toTexturePosition(),
        }) catch @panic("oom, can't append tile");
    }
}

fn parseObjectLayer(layer: *const tiled.Layer) void {
    for (layer.objects) |object| {
        const tileSet = blk: for (level.tileSets) |tileSet| {
            if (object.gid < tileSet.max) break :blk tileSet;
        } else unreachable;

        const id = object.gid - tileSet.min;
        if (id == 1) {
            // 角色，目前特殊处理一下，后续想想角色应该加入到地图还是单独管理
            playerStart = object.position.addY(-object.size.y);
            continue;
        }
        const image = zhu.assets.getImage(tileSet.images[id]);

        tiles.append(zhu.assets.allocator, .{
            .image = image.sub(.init(.zero, object.size)),
            .position = object.position.addY(-object.size.y),
        }) catch @panic("oom, can't append tile");
    }
}

pub fn worldToTilePosition(pos: zhu.Vector2) tiled.Position {
    const tilePos = pos.div(level.tileSize).floor();
    const x: u32 = @intFromFloat(tilePos.x);
    const y: u32 = @intFromFloat(tilePos.y);
    return .{ .x = x, .y = y };
}

pub fn worldToTileIndex(pos: zhu.Vector2) usize {
    const tilePos = worldToTilePosition(pos);
    if (tilePos.x < 0 or tilePos.y < 0) return 0;
    if (tilePos.x >= level.width or tilePos.y >= level.height) return 0;
    return tilePos.y * level.width + tilePos.x;
}

pub fn tileIndexToWorld(index: usize) zhu.Vector2 {
    const x: f32 = @floatFromInt(index % level.width);
    const y: f32 = @floatFromInt(index / level.width);
    return level.tileSize.mul(.xy(x, y));
}

pub fn clamp(old: Vector2, new: Vector2, size: Vector2) Vector2 {
    const clampedX = clampX(old, .xy(new.x, old.y), size);
    const clampedY = clampY(old, .xy(old.x, new.y), size);
    return .xy(clampedX.x, clampedY.y);
}

const epsilon = zhu.Vector2.one.scale(-zhu.math.epsilon);
fn clampX(old: Vector2, new: Vector2, size: Vector2) Vector2 {
    const sz = size.add(epsilon);

    if (new.x < old.x) { // 向左移动
        var tileIndex = worldToTileIndex(new);
        if (level.states[tileIndex] == 1) { // 左上角碰撞
            return tileIndexToWorld(tileIndex + 1);
        }
        tileIndex = worldToTileIndex(new.addY(sz.y));
        if (level.states[tileIndex] == 1) { // 左下角碰撞
            return tileIndexToWorld(tileIndex + 1);
        }
    } else if (new.x > old.x) { // 向右移动
        const offset = level.tileSize.x - size.x;
        var tileIndex = worldToTileIndex(new.addX(sz.x));
        if (level.states[tileIndex] == 1) { // 右上角碰撞
            return tileIndexToWorld(tileIndex - 1).addX(offset);
        }
        tileIndex = worldToTileIndex(new.add(sz));
        if (level.states[tileIndex] == 1) { // 右下角碰撞
            return tileIndexToWorld(tileIndex - 1).addX(offset);
        }
    }
    return new;
}

fn clampY(old: Vector2, new: Vector2, size: Vector2) Vector2 {
    const w = level.width;

    const sz = size.add(epsilon);
    if (new.y < old.y) { // 向上移动
        var tileIndex = worldToTileIndex(new);
        if (level.states[tileIndex] == 1) { // 左上角碰撞
            return tileIndexToWorld(tileIndex + w);
        }
        tileIndex = worldToTileIndex(new.addX(sz.x));
        if (level.states[tileIndex] == 1) { // 右上角碰撞
            return tileIndexToWorld(tileIndex + w);
        }
    } else if (new.y > old.y) { // 向下移动
        var tileIndex = worldToTileIndex(new.addY(sz.y));
        const offset = level.tileSize.y - size.y;
        if (level.states[tileIndex] == 1) {
            return tileIndexToWorld(tileIndex - w).addY(offset);
        }

        tileIndex = worldToTileIndex(new.add(sz));
        if (level.states[tileIndex] == 1) {
            return tileIndexToWorld(tileIndex - w).addY(offset);
        }
    }
    return new;
}

pub fn draw() void {
    for (level.layers) |*layer| {
        if (layer.type == .image) drawImageLayer(layer);
    }

    batch.vertexBuffer.appendSliceAssumeCapacity(tileVertexes.items);

    for (tiles.items) |tile| {
        batch.drawImage(tile.image, tile.position, .{});
    }

    for (0..level.height) |y| {
        for (0..level.width) |x| {
            const index = y * level.width + x;
            const state = level.states[index];
            if (state == 0) continue;

            const pos = level.tileSize.mul(.xy(@floatFromInt(x), @floatFromInt(y)));
            batch.debugDraw(.init(pos, level.tileSize));
        }
    }
}

fn drawImageLayer(layer: *const tiled.Layer) void {
    zhu.camera.modeEnum = .window;
    defer zhu.camera.modeEnum = .world;

    if (layer.repeatY) {
        const posY = zhu.camera.position.y * layer.parallaxY;
        var y = -@mod(posY, layer.height);
        while (y < window.size.y) : (y += layer.height) {
            batch.draw(layer.image, layer.offset.addXY(0, y));
        }
    }

    if (layer.repeatX) {
        const posX = zhu.camera.position.x * layer.parallaxX;
        var x = -@mod(posX, layer.width);
        while (x < window.size.x) : (x += layer.width) {
            batch.draw(layer.image, layer.offset.addXY(x, 0));
        }
    }
}
