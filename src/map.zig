const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const assets = @import("assets.zig");
const c = @import("c.zig");

pub const SIZE: math.Vector = .init(1000, 800);

var map: gfx.Texture = undefined;
var mapShade: gfx.Texture = undefined;
var mapBack: gfx.Texture = undefined;
var mapBlock: ?std.StaticBitSet(SIZE.x * SIZE.y) = null;

pub fn init() void {
    map = assets.loadTexture("assets/map1.png", SIZE);
    mapShade = assets.loadTexture("assets/map1_shade.png", SIZE);
    mapBack = assets.loadTexture("assets/map1_back.png", SIZE);

    const file = assets.File.load("assets/map1_block.png", callback);
    if (file.data.len != 0) initMapBlock(file.data);

    audio.playMusic("assets/1.ogg");
}

pub fn canWalk(pos: math.Vector) bool {
    const x, const y = .{ @round(pos.x), @round(pos.y) };

    if (x < 0 or x >= SIZE.x or y < 0 or y >= SIZE.y) return false;
    if (mapBlock) |block| {
        return !block.isSet(@intFromFloat(x + y * SIZE.x));
    } else return false;
}

fn callback(allocator: std.mem.Allocator, buffer: *[]const u8) void {
    const image = c.stbImage.loadFromMemory(buffer.*) catch unreachable;
    defer c.stbImage.unload(image);

    buffer.* = allocator.dupe(u8, image.data) catch unreachable;
    initMapBlock(buffer.*);
}

fn initMapBlock(buffer: []const u8) void {
    const data: []const u32 = @ptrCast(@alignCast(buffer));
    std.debug.assert(data.len == SIZE.x * SIZE.y);

    var blocks: std.StaticBitSet(SIZE.x * SIZE.y) = .initEmpty();
    for (data, 0..) |color, index| {
        if (color == 0xFF000000) blocks.set(index);
    }
    mapBlock = blocks;
}

pub fn drawBackground() void {
    gfx.draw(mapBack, .zero);
    gfx.draw(map, .zero);
}

pub fn drawForeground() void {
    gfx.draw(mapShade, .zero);
}
