const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

const scene = @import("scene.zig");
const map = @import("map.zig");
const context = @import("context.zig");
const npc = @import("npc.zig");
const player = @import("player.zig");
const menu = @import("menu.zig");

var enemyIndex: u16 = 0;
var enemy: npc.Character = undefined;

var texture: gfx.Texture = undefined;
var menuNames: [4][]const u8 = .{ "攻击", "状态", "物品", "逃走" };
var menuIndex: u8 = 0;

var playerTurn: bool = true;
var damage: u16 = 0;
var damageTimer: window.Timer = .init(0.5);

pub fn init() void {
    std.log.info("battle init", .{});
    texture = gfx.loadTexture("assets/pic/fightbar.png", .init(448, 112));
    damageTimer.stop();
}

pub fn enter() void {
    enemyIndex = context.battleNpcIndex;
    enemy = npc.zon[enemyIndex];
    map.linkIndex = 13;
    _ = map.enter();
    menu.active = 7;
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.ESCAPE)) scene.changeScene(.world);

    if (damage != 0) {
        if (damageTimer.isFinishedAfterUpdate(delta)) damage = 0;
    }

    const menuEvent = menu.update();
    if (menuEvent) |event| updateMenuEvent(event);
}

pub fn updateMenuEvent(event: u8) void {
    switch (event) {
        0 => updateAttack(),
        1 => {
            // 状态
        },
        2 => {
            // 物品
        },
        3 => {
            // 逃走
            scene.changeScene(.world);
        },
        else => unreachable,
    }
}

pub fn updateAttack() void {
    damage = player.attack * 2 - enemy.defend;
    if (damage <= 10) damage = randomU16(0, 10) else {
        damage += randomU16(0, damage);
    }
    damageTimer.reset();
}

fn randomU16(min: u16, max: u16) u16 {
    return math.random().intRangeLessThanBiased(u16, min, max);
}

pub fn draw() void {
    map.draw();

    camera.mode = .local;
    defer camera.mode = .world;
    var buffer: [100]u8 = undefined;

    // 战斗人物
    camera.draw(player.battleTexture(), .init(130, 220));

    // 如果有伤害
    if (damage != 0) {
        const y = std.math.lerp(190, 230, 1 - damageTimer.progress());
        const text = zhu.format(&buffer, "-{}", .{damage});
        camera.drawText(text, .init(470, y));
    }

    // 战斗 NPC
    camera.draw(npc.battleTexture(enemyIndex), .init(465, 237));

    const position = gfx.Vector.init(96, 304);

    // 状态栏背景
    camera.draw(texture, position);
    // 角色的头像
    camera.draw(player.photo(), position.addXY(10, 10));

    const format = "生命：{:8}\n攻击：{:8}\n防御：{:8}\n等级：{:8}";
    var text = zhu.format(&buffer, format, .{
        player.health,
        player.attack,
        player.defend,
        player.level,
    });
    camera.drawColorText(text, position.addXY(50, 5), .black);

    // 敌人的头像
    const npcTexture = npc.photo(context.battleNpcIndex);
    camera.draw(npcTexture, position.addXY(265, 26));

    text = zhu.format(&buffer, format, .{
        enemy.health,
        enemy.attack,
        enemy.defend,
        enemy.level,
    });
    camera.drawColorText(text, position.addXY(305, 5), .black);

    menu.draw();
}

pub fn deinit() void {
    npc.deinit();
}
