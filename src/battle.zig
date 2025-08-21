const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const scene = @import("scene.zig");
const map = @import("map.zig");
const context = @import("context.zig");
const npc = @import("npc.zig");
const player = @import("player.zig");

var enemy: u16 = 0;
var texture: gfx.Texture = undefined;

pub fn init() void {
    std.log.info("battle init", .{});
    texture = gfx.loadTexture("assets/pic/fightbar.png", .init(448, 112));
}

pub fn enter() void {
    enemy = context.battleNpcIndex;
    map.linkIndex = 13;
    _ = map.enter();
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.ESCAPE)) {
        scene.changeScene(.world);
    }

    _ = delta;
}

pub fn draw() void {
    map.draw();

    camera.mode = .local;
    defer camera.mode = .world;

    const position = gfx.Vector.init(96, 304);

    camera.draw(texture, position);
    camera.draw(player.photo(), position.addXY(10, 10));
}

pub fn deinit() void {
    npc.deinit();
}
