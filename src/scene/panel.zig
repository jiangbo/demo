const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");
const camera = @import("../camera.zig");
const battle = @import("battle.zig");

pub var active: bool = true;

var attack: gfx.Texture = undefined;
var attackHover: gfx.Texture = undefined;
var item: gfx.Texture = undefined;
var itemHover: gfx.Texture = undefined;
var skill: gfx.Texture = undefined;
var skillHover: gfx.Texture = undefined;
var background: gfx.Texture = undefined;
var health: gfx.Texture = undefined;
var mana: gfx.Texture = undefined;

var selectedType: usize = 0;
var selectedPlayer: usize = 0;

pub fn init() void {
    attack = gfx.loadTexture("assets/fight/fm_b1_1.png", .init(38, 36));
    attackHover = gfx.loadTexture("assets/fight/fm_b1_2.png", .init(38, 36));
    item = gfx.loadTexture("assets/fight/fm_b2_1.png", .init(38, 36));
    itemHover = gfx.loadTexture("assets/fight/fm_b2_2.png", .init(38, 36));
    skill = gfx.loadTexture("assets/fight/fm_b3_1.png", .init(38, 36));
    skillHover = gfx.loadTexture("assets/fight/fm_b3_2.png", .init(38, 36));
    background = gfx.loadTexture("assets/fight/fm_bg.png", .init(319, 216));
    health = gfx.loadTexture("assets/fight/fm_s1.png", .init(129, 17));
    mana = gfx.loadTexture("assets/fight/fm_s2.png", .init(129, 17));
}

pub fn update(_: f32) void {
    if (window.isAnyKeyRelease(&.{ .LEFT, .A })) {
        selectedType = (selectedType + 2) % 3;
    }
    if (window.isAnyKeyRelease(&.{ .RIGHT, .D })) {
        selectedType = (selectedType + 1) % 3;
    }

    if (window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) {
        battle.startAttack(selectedPlayer);
    }

    if (window.isKeyRelease(.TAB)) {
        selectedPlayer = (selectedPlayer + 1) % 3;
        battle.attackIndex = selectedPlayer;
    }
}

pub fn render() void {
    const offset = gfx.Vector.init(200, 385);
    camera.draw(background, offset);

    var texture = if (selectedType == 0) attackHover else attack;
    camera.draw(texture, offset.add(.init(142, 68)));

    texture = if (selectedType == 1) itemHover else item;
    camera.draw(texture, offset.add(.init(192, 68)));

    texture = if (selectedType == 2) skillHover else skill;
    camera.draw(texture, offset.add(.init(242, 68)));

    // 头像
    const player = &world.players[selectedPlayer];
    camera.draw(player.battleFace, offset);

    // 状态条
    drawName(player.name, offset.add(.init(180, 114)));
    camera.draw(health, offset.add(.init(141, 145)));
    camera.draw(mana, offset.add(.init(141, 171)));
}

fn drawName(name: []const u8, pos: gfx.Vector) void {
    camera.drawTextOptions(.{
        .text = name,
        .position = pos,
        .color = gfx.Color{ .g = 0.05, .b = 0.16, .a = 1 },
    });
}

fn drawTextOptions(comptime fmt: []const u8, options: anytype) void {
    var buffer: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, fmt, options.args);
    camera.drawTextOptions(.{
        .text = text catch unreachable,
        .position = options.position,
        .color = options.color,
    });
}
