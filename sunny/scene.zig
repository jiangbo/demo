const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const player = @import("player.zig");

var help = false;
var debug = false;

const level: tiled.Map = @import("zon/level1.zon");
var texture: zhu.graphics.Texture = undefined;
var tileVertexes: std.ArrayList(batch.Vertex) = .empty;
var tiles: std.ArrayList(tiled.Tile) = .empty;

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
    texture = firstImage.texture;
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
            .texture = image.area.toVector4(),
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
            player.init(object.position.addY(-object.size.y));
            continue;
        }
        const image = zhu.assets.getImage(tileSet.images[id]);

        tiles.append(zhu.assets.allocator, .{
            .image = image.sub(.init(.zero, object.size)),
            .position = object.position.addY(-object.size.y),
        }) catch @panic("oom, can't append tile");
    }
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.H)) help = !help;
    if (window.isKeyRelease(.X)) debug = !debug;

    if (window.isKeyDown(.LEFT_ALT) and window.isKeyRelease(.ENTER)) {
        return window.toggleFullScreen();
    }

    const distance: f32 = std.math.round(300 * delta);
    zhu.camera.control(distance);

    player.update(delta);
}

pub fn draw() void {
    zhu.batch.beginDraw(.black);
    defer zhu.batch.endDraw();

    for (level.layers) |*layer| {
        if (layer.type == .image) drawImageLayer(layer);
    }

    batch.drawVertices(texture, tileVertexes.items);

    for (tiles.items) |tile| {
        batch.drawImage(tile.image, tile.position, .{});
    }

    player.draw();

    if (help) drawHelpInfo() else if (debug) window.drawDebugInfo();
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

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关闭
    ;
    zhu.text.drawColor(text, .xy(10, 10), .green);
}
