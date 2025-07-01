const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const imageNames: []const [:0]const u8 = @import("zon/npcTex.zon");
pub var npcTextures: [imageNames.len]gfx.Texture = undefined;
pub const npcs: []const Character = @import("zon/npc.zon");

pub fn init() void {
    for (imageNames, &npcTextures) |name, *texture| {
        texture.* = gfx.loadTexture(name, .init(64, 128));
    }
}

pub fn render() void {
    const area = gfx.Rectangle.init(.zero, .init(32, 32));
    for (npcs) |value| {
        if (value.show) {
            const texture = npcTextures[value.pic].subTexture(area);
            camera.draw(texture, .init(value.x, value.y));
        }
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
    way: u8,
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
