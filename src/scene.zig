const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");

const titleScene = @import("scene/title.zig");
const worldScene = @import("scene/world.zig");
const battleScene = @import("scene/battle.zig");

const SceneType = enum { title, world, battle };
var currentSceneType: SceneType = .battle;

const SIZE: gfx.Vector = .init(1000, 800);
pub var camera: gfx.Camera = undefined;
pub var cursor: gfx.Texture = undefined;
var cursorTexture: gfx.Texture = undefined;

const MAX_COUNT = 100;

var vertexBuffer: [MAX_COUNT * 4]gfx.Vertex = undefined;
var indexBuffer: [MAX_COUNT * 6]u16 = undefined;

var texture: gfx.Texture = undefined;

pub fn init() void {
    var index: u16 = 0;
    while (index < MAX_COUNT) : (index += 1) {
        indexBuffer[index * 6 + 0] = index * 4 + 0;
        indexBuffer[index * 6 + 1] = index * 4 + 1;
        indexBuffer[index * 6 + 2] = index * 4 + 2;
        indexBuffer[index * 6 + 3] = index * 4 + 0;
        indexBuffer[index * 6 + 4] = index * 4 + 2;
        indexBuffer[index * 6 + 5] = index * 4 + 3;
    }
    camera = .init(.init(.zero, window.size), SIZE, &vertexBuffer, &indexBuffer);

    titleScene.init();
    worldScene.init(&camera);
    battleScene.init();
    window.showCursor(false);
    cursorTexture = gfx.loadTexture("assets/mc_1.png", .init(32, 32));
    texture = gfx.loadTexture("assets/fight/p1.png", .init(960, 240));
    cursor = cursorTexture;
    enter();
}

pub fn enter() void {
    sceneCall("enter", .{});
}

pub fn exit() void {
    sceneCall("exit", .{});
}

pub fn changeScene() void {
    exit();
    const next: usize = @intFromEnum(currentSceneType);
    const len = std.enums.values(SceneType).len;
    currentSceneType = @enumFromInt((next + 1) % len);
    enter();
}

pub fn update(delta: f32) void {
    cursor = cursorTexture;
    sceneCall("update", .{delta});
}

const sgl = @import("sokol").gl;
pub fn render() void {
    camera.beginDraw(.{ .a = 1 });
    defer camera.endDraw();

    sceneCall("render", .{&camera});

    camera.draw(cursor, window.mousePosition.add(camera.rect.min));
    // gfx.drawQuad();

    var tex = texture.subTexture(.init(.zero, .init(240, 240)));
    camera.batchDraw(tex, .init(0, 0));

    tex = texture.subTexture(.init(.init(240, 0), .init(240, 240)));
    camera.batchDraw(tex, .init(800 - 240, 0));

    tex = texture.subTexture(.init(.init(480, 0), .init(240, 240)));
    camera.batchDraw(tex, .init(0, 600 - 240));

    tex = texture.subTexture(.init(.init(720, 0), .init(240, 240)));
    camera.batchDraw(tex, .init(800 - 240, 600 - 240));
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    switch (currentSceneType) {
        .title => window.call(titleScene, function, args),
        .world => window.call(worldScene, function, args),
        .battle => window.call(battleScene, function, args),
    }
}
