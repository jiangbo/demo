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

    // 状态栏背景
    camera.draw(texture, position);
    // 角色的头像
    camera.draw(player.photo(), position.addXY(10, 10));

    var buffer: [100]u8 = undefined;
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
        npc.zon[enemy].health,
        npc.zon[enemy].attack,
        npc.zon[enemy].defend,
        npc.zon[enemy].level,
    });
    camera.drawColorText(text, position.addXY(305, 5), .black);
}

pub fn deinit() void {
    npc.deinit();
}
