const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

const imageNames: []const [:0]const u8 = @import("zon/npcTex.zon");
pub var npcTextures: [imageNames.len]gfx.Texture = undefined;
pub var npcs: [10]Character = @import("zon/npc.zon");

pub fn init() void {
    for (imageNames, &npcTextures) |name, *texture| {
        texture.* = gfx.loadTexture(name, .init(64, 128));
    }
}

pub fn update() void {
    for (&npcs) |*npc| {
        if (zhu.randU8(0, 100) > 80) {
            npc.facing = zhu.randEnum(gfx.FourDirection);
        }
    }
}

pub fn render() void {
    for (&npcs) |npc| {
        if (!npc.show) continue;

        const pos: gfx.Vector = switch (npc.facing) {
            .up => .{ .x = 0, .y = 64 },
            .down => .{ .x = 0, .y = 0 },
            .left => .{ .x = 32, .y = 0 },
            .right => .{ .x = 96, .y = 0 },
        };
        const area = gfx.Rectangle.init(pos, .init(32, 32));
        const texture = npcTextures[npc.pic].subTexture(area);
        camera.draw(texture, .init(npc.x, npc.y));
    }
}

pub const Character = struct {
    id: u32,
    pic: u8,
    enemy: bool,
    talkNum: u8,
    active: bool,
    show: bool,
    name: []const u8,
    width: u16,
    height: u16,
    x: f32,
    y: f32,
    oldX: u16,
    oldY: u16,
    facing: gfx.FourDirection = .down,
    stats: u8,
    level: u8,
    exp: u32,
    lift: u16,
    maxLift: u16,
    attack: u16,
    defend: u16,
    speed: u8,
    goods: [1]u32,
    money: u32,
};
