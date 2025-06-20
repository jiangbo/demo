const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;
const math = @import("zhu").math;

const actor = @import("actor.zig");

var mapTexture: gfx.Texture = undefined;

const Map = struct {
    indexes: []const u16,
    items: []const struct { index: u16, item: u16 },
};

const map: Map = @import("zon/map.zon");

var tiles: [500]camera.Vertex = undefined;
var tileIndex: usize = 0;
const Status = union(enum) { normal, talk: usize };
var status: Status = .normal;

const Talk = struct {
    name: []const u8,
    content: []const u8,
    next: usize = 0,
};
const talks: []const Talk = @import("zon/talk.zon");

var talkTexture: gfx.Texture = undefined;

pub fn init() void {
    mapTexture = gfx.loadTexture("assets/pic/maps.png", .init(640, 1536));

    // 背景
    for (map.indexes, 0..) |mapIndex, index| {
        if (mapIndex == std.math.maxInt(u16)) continue;

        const tile = mapTexture.subTexture(getAreaFromIndex(mapIndex));
        tiles[tileIndex] = .{
            .position = getAreaFromIndex(index).min,
            .size = .init(32, 32),
            .texture = tile.area.toVector4(),
        };
        tileIndex += 1;
    }

    // 装饰
    for (map.items) |item| {
        const tile = mapTexture.subTexture(getAreaFromIndex(item.item));
        tiles[tileIndex] = .{
            .position = getAreaFromIndex(item.index).min,
            .size = .init(32, 32),
            .texture = tile.area.toVector4(),
        };
        tileIndex += 1;
    }

    talkTexture = gfx.loadTexture("assets/pic/talkbar.png", .init(640, 96));

    status = .{ .talk = 1 };

    actor.init();

    // window.playMusic("assets/voc/back.ogg");
}

fn getAreaFromIndex(index: usize) gfx.Rectangle {
    const row: f32 = @floatFromInt(index / 20);
    const col: f32 = @floatFromInt(index % 20);
    return .init(.init(col * 32, row * 32), .init(32, 32));
}

pub fn update(delta: f32) void {
    _ = delta;

    switch (status) {
        .normal => {},
        .talk => |talkId| updateTalk(talkId),
    }
}

fn updateTalk(talkId: usize) void {
    if (!confirm()) return;

    const next = talks[talkId].next;
    status = if (next == 0) .normal else .{ .talk = next };
}

fn confirm() bool {
    return window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER });
}

pub fn enter() void {}

pub fn exit() void {}

pub fn render() void {
    camera.drawVertex(mapTexture, tiles[0..tileIndex]);

    const animation = actor.playerAnimation.get(actor.playerDirection);
    camera.draw(animation.currentTexture(), actor.playerPosition);

    switch (status) {
        .normal => {},
        .talk => |talkId| renderTalk(talkId),
    }
}

fn renderTalk(talkId: usize) void {
    camera.draw(talkTexture, .init(0, 384));

    const downAnimation = actor.playerAnimation.get(.down);
    const tex = downAnimation.texture.mapTexture(downAnimation.frames[0]);
    camera.draw(tex, .init(30, 396));

    const talk = talks[talkId];
    const nameColor = gfx.color(1, 1, 0, 1);
    camera.drawColorText(talk.name, .init(18, 445), nameColor);

    camera.drawColorText(talk.content, .init(123, 403), .{ .w = 1 });
    camera.drawColorText(talk.content, .init(120, 400), .one);
}
