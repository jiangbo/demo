const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");

pub const Enemy = struct {
    active: bool = false,
    texture: gfx.Texture = undefined,
};

pub const Panel = struct {
    attack: gfx.Texture = undefined,
    item: gfx.Texture = undefined,
    skill: gfx.Texture = undefined,
    background: gfx.Texture = undefined,
    health: gfx.Texture = undefined,
    mana: gfx.Texture = undefined,
};

var background: gfx.Texture = undefined;
var enemyTexture: gfx.Texture = undefined;
var enemies: [3]Enemy = undefined;
var panel: Panel = undefined;
var displayPanel: bool = true;

pub fn init() void {
    background = gfx.loadTexture("assets/fight/f_scene.png", .init(800, 600));
    enemyTexture = gfx.loadTexture("assets/fight/enemy.png", .init(1920, 240));

    panel = .{
        .attack = gfx.loadTexture("assets/fight/fm_b1_1.png", .init(38, 36)),
        .item = gfx.loadTexture("assets/fight/fm_b2_1.png", .init(38, 36)),
        .skill = gfx.loadTexture("assets/fight/fm_b3_1.png", .init(38, 36)),
        .background = gfx.loadTexture("assets/fight/fm_bg.png", .init(319, 216)),
        .health = gfx.loadTexture("assets/fight/fm_s1.png", .init(129, 17)),
        .mana = gfx.loadTexture("assets/fight/fm_s2.png", .init(129, 17)),
    };
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

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn render(camera: *gfx.Camera) void {
    camera.draw(background, .init(0, 0));

    var offset = gfx.Vector.init(120, 120).scale(-1);

    const player1 = &world.players[0];
    camera.draw(player1.attackTexture, offset.add(.init(617, 258)));

    const player2 = &world.players[1];
    camera.draw(player2.attackTexture, offset.add(.init(695, 361)));

    const player3 = &world.players[2];
    camera.draw(player3.attackTexture, offset.add(.init(588, 417)));

    offset = gfx.Vector.init(-160, -120);
    camera.draw(enemies[0].texture, offset.add(.init(253, 250)));
    camera.draw(enemies[1].texture, offset.add(.init(179, 345)));
    camera.draw(enemies[2].texture, offset.add(.init(220, 441)));

    offset = gfx.Vector.init(200, 385);
    if (displayPanel) {
        camera.draw(panel.background, offset);
        camera.draw(panel.attack, offset.add(.init(142, 68)));
        camera.draw(panel.item, offset.add(.init(192, 68)));
        camera.draw(panel.skill, offset.add(.init(242, 68)));

        // 头像
        const player = &world.players[0];
        camera.draw(player.battleFace, offset);

        // 状态条
        camera.draw(panel.health, offset.add(.init(141, 145)));
        camera.draw(panel.mana, offset.add(.init(141, 171)));
    }
}
