const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");
const math = @import("math.zig");
const audio = @import("audio.zig");
const assets = @import("assets.zig");
const c = @import("c.zig");
const scene = @import("scene.zig");

pub const SIZE: math.Vector = .init(1000, 800);
const PLAYER_OFFSET: math.Vector = .init(120, 220);
const NPC_SIZE: math.Vector = .init(240, 240);
const NPC_AREA: math.Vector = .init(80, 100);

const Action = *const fn () void;
pub const NPC = struct {
    position: math.Vector,
    texture: ?gfx.Texture = null,
    area: math.Rectangle = .{},
    keyTrigger: bool = true,
    action: *const fn () void = undefined,

    pub fn init(x: f32, y: f32, path: ?[:0]const u8, action: Action) NPC {
        var self: NPC = .{ .position = .init(x, y), .action = action };

        if (path) |p| self.texture = assets.loadTexture(p, NPC_SIZE);
        self.area = .init(self.position.sub(.init(40, 60)), NPC_AREA);
        return self;
    }
};

const Map = struct {
    map: gfx.Texture,
    mapShade: gfx.Texture,
    mapBack: ?gfx.Texture = null,
    mapBlock: ?std.StaticBitSet(SIZE.x * SIZE.y) = null,
    npcArray: [3]NPC = undefined,
};

var index: usize = maps.len - 1;
var maps: [2]Map = undefined;

fn npc1Action() void {
    std.log.info("npc1 action", .{});
}

fn npc2Action() void {
    std.log.info("npc2 action", .{});
}

pub fn init() void {
    maps[0] = Map{
        .map = assets.loadTexture("assets/map1.png", SIZE),
        .mapShade = assets.loadTexture("assets/map1_shade.png", SIZE),
        .mapBack = assets.loadTexture("assets/map1_back.png", SIZE),
        .npcArray = .{
            .init(800, 300, "assets/npc1.png", npc1Action),
            .init(700, 280, "assets/npc2.png", npc2Action),
            .init(0, 0, null, changeMap0),
        },
    };
    maps[0].npcArray[2].area = .init(.{ .y = 400 }, .init(20, 600));
    maps[0].npcArray[2].keyTrigger = false;

    std.mem.sort(NPC, &maps[0].npcArray, {}, struct {
        fn lessThan(_: void, a: NPC, b: NPC) bool {
            return a.position.y < b.position.y;
        }
    }.lessThan);

    maps[1] = Map{
        .map = assets.loadTexture("assets/map2.png", SIZE),
        .mapShade = assets.loadTexture("assets/map2_shade.png", SIZE),
        .npcArray = .{
            .init(800, 300, "assets/npc1.png", npc1Action),
            .init(700, 280, "assets/npc2.png", npc2Action),
            .init(0, 0, null, changeMap1),
        },
    };
    maps[1].npcArray[2].area = .init(.init(980, 400), .init(20, 600));
    maps[1].npcArray[2].keyTrigger = false;

    const file = assets.File.load("assets/map1_block.png", callback);
    if (file.data.len != 0) initMapBlock(file.data);

    changeMap();
}

fn changeMap0() void {
    changeMap();
    scene.position.x = SIZE.x - 25;
}

fn changeMap1() void {
    changeMap();
    scene.position.x = 25;
}

pub fn changeMap() void {
    index = (index + 1) % maps.len;
    switch (index) {
        0 => audio.playMusic("assets/1.ogg"),
        1 => audio.playMusic("assets/2.ogg"),
        else => unreachable,
    }

    if (maps[index].mapBlock == null and index == 0) {
        const file = assets.File.load("assets/map1_block.png", callback);
        if (file.data.len != 0) initMapBlock(file.data);
    }

    if (maps[index].mapBlock == null and index == 1) {
        const file = assets.File.load("assets/map2_block.png", callback);
        if (file.data.len != 0) initMapBlock(file.data);
    }
}

pub fn canWalk(pos: math.Vector) bool {
    const x, const y = .{ @round(pos.x), @round(pos.y) };

    if (x < 0 or x >= SIZE.x or y < 0 or y >= SIZE.y) return false;
    if (maps[index].mapBlock) |block| {
        return !block.isSet(@intFromFloat(x + y * SIZE.x));
    } else return false;
}

pub fn npcSlice() []NPC {
    return maps[index].npcArray[0..];
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
    for (data, 0..) |color, i| if (color == 0xFF000000) blocks.set(i);

    maps[index].mapBlock = blocks;
}

pub fn drawBackground() void {
    if (maps[index].mapBack) |back| gfx.draw(back, .zero);
    gfx.draw(maps[index].map, .zero);
}

pub fn drawForeground() void {
    gfx.draw(maps[index].mapShade, .zero);
}
