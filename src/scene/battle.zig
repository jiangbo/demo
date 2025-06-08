const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");
const camera = @import("../camera.zig");
const panel = @import("panel.zig");

pub const Enemy = struct {
    active: bool = false,
    texture: gfx.Texture = undefined,
};

var background: gfx.Texture = undefined;
var enemyTexture: gfx.Texture = undefined;
var enemies: [3]Enemy = undefined;

var attackTimer: window.Timer = .init(0.4);
pub var attackIndex: usize = 0;

pub fn init() void {
    background = gfx.loadTexture("assets/fight/f_scene.png", .init(800, 600));
    enemyTexture = gfx.loadTexture("assets/fight/enemy.png", .init(1920, 240));
    panel.init();
    attackTimer.stop();
}

pub fn enter() void {
    for (&enemies) |*enemy| {
        enemy.active = true;
        const area = gfx.Rectangle.init(.zero, .init(480, 240));
        enemy.texture = enemyTexture.subTexture(area);
    }

    window.playMusic("assets/fight/fight.ogg");
}

pub fn exit() void {
    window.stopMusic();
}

pub fn startAttack(index: usize) void {
    attackTimer.reset();
    attackIndex = index;
}

pub fn update(delta: f32) void {
    attackTimer.update(delta);
    if (panel.active) panel.update(delta);
}

pub fn render() void {
    camera.draw(background, .init(0, 0));

    var offset = gfx.Vector.init(120, 120).scale(-1);

    const player1 = &world.players[0];
    renderAttack(0, player1.battleTexture, offset.add(.init(617, 258)));

    const player2 = &world.players[1];
    renderAttack(1, player2.battleTexture, offset.add(.init(695, 361)));

    const player3 = &world.players[2];
    renderAttack(2, player3.battleTexture, offset.add(.init(588, 417)));

    offset = gfx.Vector.init(-160, -120);
    camera.draw(enemies[0].texture, offset.add(.init(253, 250)));
    camera.draw(enemies[1].texture, offset.add(.init(179, 345)));
    camera.draw(enemies[2].texture, offset.add(.init(220, 441)));

    if (panel.active) panel.render();
}

fn renderAttack(index: usize, texture: gfx.Texture, pos: gfx.Vector) void {
    const size = gfx.Vector.init(240, 240);

    var area = gfx.Rectangle.init(.init(0, 0), size);
    if (attackTimer.isRunning() and attackIndex == index) {
        area = .init(.init(240, 0), size);
    }
    camera.draw(texture.subTexture(area), pos);
}
