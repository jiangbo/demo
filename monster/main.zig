const std = @import("std");
const zhu = @import("zhu");

const tiled = zhu.extend.tiled;
const gui = @import("gui.zig");
const scene = @import("scene.zig");
const hud = @import("hud.zig");
const title = @import("title.zig");
const ctx = @import("context.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [128]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;
const tileSets: []const tiled.TileSet = @import("zon/tile.zon");
const atlas: zhu.Atlas = @import("zon/atlas.zon");
const fontZon: zhu.text.BitMapFont = @import("zon/font.zon");

var registry: zhu.ecs.Registry = undefined;
var battleLoaded: bool = false;

pub fn init(allocator: zhu.Allocator) void {
    zhu.audio.init(44100 / 2, &soundBuffer);

    vertexBuffer = allocator.alloc(zhu.batch.Vertex, 8000);
    zhu.graphics.frameStats(true);
    zhu.assets.loadAtlas(atlas);
    zhu.batch.init(vertexBuffer, &commandBuffer);
    const whiteCircle = zhu.getImage("circle.png");
    const area: zhu.Rect = .init(.xy(16, 16), .xy(32, 32));
    zhu.batch.whiteImage = whiteCircle.sub(area);

    tiled.init(tileSets);

    const fontImage = zhu.assets.loadImage("assets/font.png");
    zhu.text.initBitMapFont(fontImage, fontZon, 32);

    registry = .init(allocator.raw);

    gui.init();
    ctx.init();
    scene.init();
    hud.init();
    title.init();
    title.enter();
}

pub fn event(ev: *const zhu.window.Event) void {
    gui.event(ev);
}

pub fn frame(delta: f32) void {
    if (ctx.pendingScene) |s| {
        switchScene(s);
    }
    switch (ctx.currentScene) {
        .battle => {
            const scaled = delta * ctx.timeScale;
            gui.update(&registry, scaled);
            ctx.update(scaled);
            scene.update(&registry, scaled);
            hud.update(delta);

            zhu.batch.beginDraw(tiled.backgroundColor orelse .black);
            scene.draw(&registry);
            hud.draw();
        },
        .title => {
            gui.update(&registry, delta);
            title.update(delta);

            zhu.batch.beginDraw(tiled.backgroundColor orelse .black);
            title.draw();
        },
        .clear, .end => {
            gui.update(&registry, delta);
            zhu.batch.beginDraw(tiled.backgroundColor orelse .black);
            if (battleLoaded) {
                scene.draw(&registry);
                hud.draw();
            }
        },
    }
    zhu.batch.flush();
    gui.draw(&registry);
    zhu.batch.commit();
}

pub fn deinit(allocator: zhu.Allocator) void {
    scene.deinit();
    hud.deinit();
    title.deinit();
    ctx.deinit();
    gui.deinit();
    registry.deinit();
    allocator.free(vertexBuffer);
    zhu.audio.deinit();
}

fn switchScene(s: ctx.SceneState) void {
    const previous = ctx.currentScene;
    const pushBattleOverlay = previous == .battle and (s == .clear or s == .end);

    ctx.pendingScene = null;

    if (!pushBattleOverlay) {
        if (battleLoaded) {
            scene.exit();
            battleLoaded = false;
        }
        if (previous == .title) title.exit();
        registry.reset();
    }

    ctx.currentScene = s;
    switch (s) {
        .battle => {
            scene.enter();
            battleLoaded = true;
            hud.arrangeUnits();
        },
        .title => {
            title.enter();
        },
        .clear => {
            zhu.audio.playMusic("assets/audio/level-win.ogg");
        },
        .end => {
            if (ctx.win) {
                zhu.audio.playMusic("assets/audio/level-win.ogg");
            } else {
                zhu.audio.playMusic("assets/audio/violin-lose-4.ogg");
            }
        },
    }
}

pub fn main(initInfo: std.process.Init) void {
    zhu.window.run(initInfo.io, initInfo.gpa, .{
        .title = "怪物战争",
        .size = .xy(1200, 912),
        .logicSize = .xy(1600, 1216),
        .scaleEnum = .fit,
        .maxFileSize = 5 * 1024 * 1024,
    });
}
