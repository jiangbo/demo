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
// var mapBlock: ?std.StaticBitSet(SIZE.x * SIZE.y) = null;
var mapBlock: ?[SIZE.x * SIZE.y]bool = null;

pub fn init() void {
    map = assets.loadTexture("assets/map1.png", SIZE);
    mapShade = assets.loadTexture("assets/map1_shade.png", SIZE);
    mapBack = assets.loadTexture("assets/map1_back.png", SIZE);

    _ = assets.loadCallback("assets/map1_block.png", callback);
}

pub fn canWalk(pos: math.Vector) bool {
    if (pos.x < 0 or pos.y < 0) return false;
    if (mapBlock) |block| {
        return block[@intFromFloat(pos.x + pos.y * SIZE.x)];
    } else return false;
}

fn callback(responses: [*c]const assets.Response) callconv(.C) void {
    if (responses[0].failed) {
        @panic("failed to load map block");
    }

    const buffer = assets.rangeToSlice(responses[0].data);
    const image = c.stbImage.loadFromMemory(buffer) catch unreachable;
    defer c.stbImage.unload(image);

    const data: []const u32 = @ptrCast(@alignCast(image.data));
    std.debug.assert(data.len == SIZE.x * SIZE.y);

    // var blocks: std.StaticBitSet(SIZE.x * SIZE.y) = .initEmpty();
    var blocks = std.mem.zeroes([SIZE.x * SIZE.y]bool);
    for (data, 0..) |color, index| {
        if (color != 0xFF000000) blocks[index] = true;
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
