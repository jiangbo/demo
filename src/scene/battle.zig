const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");

var background: gfx.Texture = undefined;

pub fn init() void {
    background = gfx.loadTexture("assets/fight/f_scene.png", .init(800, 600));
}

pub fn enter() void {
    window.playMusic("assets/fight/fight.ogg");
}

pub fn exit() void {
    window.stopMusic();
}

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn render(camera: *gfx.Camera) void {
    camera.draw(background, .init(0, 0));

    const offset = gfx.Vector.init(120, 120).scale(-1);

    const player1 = &world.players[0];
    camera.draw(player1.attackTexture, offset.add(.init(617, 258)));

    const player2 = &world.players[1];
    camera.draw(player2.attackTexture, offset.add(.init(695, 361)));

    const player3 = &world.players[2];
    camera.draw(player3.attackTexture, offset.add(.init(588, 417)));
}
