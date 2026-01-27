const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;
const tiled = zhu.extend.tiled;
const Vector2 = zhu.Vector2;

pub const ObjectEnum = enum(u32) {
    player = zhu.imageId("textures/Actors/foxy.png"),
    eagle = zhu.imageId("textures/Actors/eagle-attack.png"),
    frog = zhu.imageId("textures/Actors/frog.png"),
    opossum = zhu.imageId("textures/Actors/opossum.png"),
    skull = zhu.imageId("textures/Props/skulls.png"),
    spike = zhu.imageId("textures/Props/spikes.png"),
    spikeTop = zhu.imageId("textures/Props/spikes-top.png"),
    cherry = zhu.imageId("textures/Items/cherry.png"),
    gem = zhu.imageId("textures/Items/gem.png"),
};

pub const TileEnum = enum {
    normal,
    solid,
    uniSolid,
    slope_0_1,
    slope_1_0,
    slope_0_2,
    slope_2_1,
    slope_1_2,
    slope_2_0,
};

pub const Object = struct {
    type: ObjectEnum,
    position: Vector2,
    size: Vector2,
    object: ?tiled.Object,
};
const map: tiled.Map = @import("zon/level1.zon");
const tileSets: []const tiled.TileSet = @import("zon/tile.zon");
var tileVertexes: std.ArrayList(batch.Vertex) = .empty;
pub var objects: std.ArrayList(Object) = .empty;
var tileStates: []TileEnum = &.{};

pub fn init() void {
    tiled.tileSets = tileSets;
    tileStates = zhu.assets.oomAlloc(TileEnum, map.width * map.height);
    @memset(tileStates, .normal);
    batch.camera.bound = map.size();

    for (map.layers) |layer| {
        if (layer.type == .tile) parseTileLayer(&layer) //
        else if (layer.type == .object) parseObjectLayer(&layer);
    }
}

pub fn deinit() void {
    objects.deinit(zhu.assets.allocator);
    tileVertexes.deinit(zhu.assets.allocator);
    zhu.assets.free(tileStates);
}

fn parseTileLayer(layer: *const tiled.Layer) void {
    const firstTileSet = tiled.getTileSetByRef(map.tileSetRefs[0]);
    var firstImage = zhu.assets.getImage(firstTileSet.image);
    for (layer.data, 0..) |gid, index| {
        if (gid == 0) continue;

        const x: f32 = @floatFromInt(index % map.width);
        const y: f32 = @floatFromInt(index / map.width);
        var pos = map.tileSize.mul(.xy(x, y));

        var image: zhu.graphics.Image = undefined;
        const tileSetRef = map.getTileSetRefByGid(gid);
        const tileSet = tiled.getTileSetByRef(tileSetRef);
        const localId = gid - tileSetRef.firstGid;

        const tile = tileSet.getTileByLocalId(localId);
        if (tileSet.columns == 0) { // 单图片瓦片集的列数
            image = zhu.assets.getImage(tile.?.id);
            pos.y = pos.y - image.area.size.y + map.tileSize.y;
            if (tile.?.id == @intFromEnum(ObjectEnum.spike)) {
                parseTileSpike(tile.?, pos);
            }
        } else {
            const area = map.tileArea(localId, tileSet.columns);
            image = firstImage.sub(area);
        }

        tileVertexes.append(zhu.assets.allocator, .{
            .position = pos,
            .size = image.area.size,
            .texturePosition = image.area.toTexturePosition(),
        }) catch @panic("oom, can't append tile");

        if (tile) |t| parseProperties(index, t); // 解析碰撞信息
    }
}

fn parseTileSpike(tile: tiled.Tile, pos: zhu.Vector2) void {
    const object = tile.objectGroup.?.objects[0];
    objects.append(zhu.assets.allocator, .{
        .type = @enumFromInt(tile.id),
        .position = pos,
        .size = object.size,
        .object = object,
    }) catch @panic("oom, can't append tile");
}

fn parseProperties(index: usize, tile: tiled.Tile) void {
    for (tile.properties) |property| {
        if (std.mem.eql(u8, property.name, "solid")) {
            if (property.value.bool) tileStates[index] = .solid;
        } else if (std.mem.eql(u8, property.name, "solid")) {
            const value = property.value.string;
            tileStates[index] =
                if (std.mem.eql(u8, value, "0_1")) .slope_0_1 //
                else if (std.mem.eql(u8, value, "1_0")) .slope_1_0 //
                else if (std.mem.eql(u8, value, "0_2")) .slope_0_2 //
                else if (std.mem.eql(u8, value, "2_0")) .slope_2_0 //
                else if (std.mem.eql(u8, value, "2_1")) .slope_2_1 //
                else if (std.mem.eql(u8, value, "1_2")) .slope_1_2 //
                else unreachable; //
        } else tileStates[index] = .normal;
    }
}

fn parseObjectLayer(layer: *const tiled.Layer) void {
    for (layer.objects) |object| {
        if (object.gid == 0) {
            std.log.info("todo 0 gid, position: {}", .{object.position});
            continue;
        }
        const tile = map.getTileByGId(object.gid).?;

        var obj: ?tiled.Object = null;
        if (tile.objectGroup) |group| obj = group.objects[0];
        objects.append(zhu.assets.allocator, .{
            .type = @enumFromInt(tile.id),
            .position = object.position.addY(-object.size.y),
            .size = object.size,
            .object = obj,
        }) catch @panic("oom, can't append tile");
    }
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
        var tileIndex = map.worldToTileIndex(new);
        if (tileStates[tileIndex] == .solid) { // 左上角碰撞
            return map.tileIndexToWorld(tileIndex + 1);
        }
        tileIndex = map.worldToTileIndex(new.addY(sz.y));
        if (tileStates[tileIndex] == .solid) { // 左下角碰撞
            return map.tileIndexToWorld(tileIndex + 1);
        }
    } else if (new.x > old.x) { // 向右移动
        const offset = map.tileSize.x - size.x;
        var tileIndex = map.worldToTileIndex(new.addX(sz.x));
        if (tileStates[tileIndex] == .solid) { // 右上角碰撞
            return map.tileIndexToWorld(tileIndex - 1).addX(offset);
        }
        tileIndex = map.worldToTileIndex(new.add(sz));
        if (tileStates[tileIndex] == .solid) { // 右下角碰撞
            return map.tileIndexToWorld(tileIndex - 1).addX(offset);
        }
    }
    return new;
}

fn clampY(old: Vector2, new: Vector2, size: Vector2) Vector2 {
    const w = map.width;

    const sz = size.add(epsilon);
    if (new.y < old.y) { // 向上移动
        var tileIndex = map.worldToTileIndex(new);
        if (tileStates[tileIndex] == .solid) { // 左上角碰撞
            return map.tileIndexToWorld(tileIndex + w);
        }
        tileIndex = map.worldToTileIndex(new.addX(sz.x));
        if (tileStates[tileIndex] == .solid) { // 右上角碰撞
            return map.tileIndexToWorld(tileIndex + w);
        }
    } else if (new.y > old.y) { // 向下移动
        var tileIndex = map.worldToTileIndex(new.addY(sz.y));
        const offset = map.tileSize.y - size.y;
        if (tileStates[tileIndex] == .solid) {
            return map.tileIndexToWorld(tileIndex - w).addY(offset);
        }

        tileIndex = map.worldToTileIndex(new.add(sz));
        if (tileStates[tileIndex] == .solid) {
            return map.tileIndexToWorld(tileIndex - w).addY(offset);
        }
    }
    return new;
}

pub fn draw() void {
    for (map.layers) |*layer| {
        if (layer.type == .image) drawImageLayer(layer);
    }

    batch.vertexBuffer.appendSliceAssumeCapacity(tileVertexes.items);

    for (0..map.height) |y| {
        for (0..map.width) |x| {
            const index = y * map.width + x;
            const state = tileStates[index];
            if (state == .normal) continue;

            const pos = map.tileSize.mul(.xy(@floatFromInt(x), @floatFromInt(y)));
            batch.debugDraw(.init(pos, map.tileSize));
        }
    }
}

fn drawImageLayer(layer: *const tiled.Layer) void {
    batch.camera.modeEnum = .window;
    defer batch.camera.modeEnum = .world;

    if (layer.repeatY) {
        const posY = batch.camera.position.y * layer.parallaxY;
        var y = -@mod(posY, layer.height);
        while (y < window.size.y) : (y += layer.height) {
            batch.draw(layer.image, layer.offset.addXY(0, y));
        }
    }

    if (layer.repeatX) {
        const posX = batch.camera.position.x * layer.parallaxX;
        var x = -@mod(posX, layer.width);
        while (x < window.size.x) : (x += layer.width) {
            batch.draw(layer.image, layer.offset.addXY(x, 0));
        }
    }
}
