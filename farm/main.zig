const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [64]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;

pub fn init() void {
    vertexBuffer = zhu.assets.oomAlloc(zhu.batch.Vertex, 4096);
    zhu.batch.init(vertexBuffer, &commandBuffer);

    zhu.audio.init(44100 / 2, &soundBuffer);

    zhu.assets.loadAtlas(@import("zon/atlas.zon"));
    const bgPath = "textures/UI/farm-rpg-bg.png";
    _ = zhu.assets.loadImage(bgPath, .xy(1280, 800));

    zhu.batch.circleImage = zhu.getImage("circle.png").?;
    const area: zhu.Rect = .init(.xy(32, 32), .xy(32, 32));
    zhu.batch.whiteImage = zhu.batch.circleImage.sub(area);

    const fontImage = zhu.assets.loadImage("font.png", .zero);
    zhu.text.init(fontImage, @import("zon/font.zon"));
    zhu.text.font.lineHeight += 2;

    zhu.window.useCursor("farm-rpg/UI/cursor.png", .{});

    scene.init();
}

var debug: bool = false;
pub fn frame(delta: f32) void {
    if (zhu.key.released(.X)) debug = !debug;
    scene.update(delta);

    zhu.batch.beginDraw();
    scene.draw();
    if (debug) zhu.debug.draw();
    zhu.batch.endDraw();
}

pub fn deinit() void {
    scene.deinit();
    zhu.audio.deinit();
    zhu.assets.free(vertexBuffer);
}

pub fn main(initInfo: std.process.Init) void {
    zhu.window.run(initInfo.io, initInfo.gpa, .{
        .title = "迷你农场",
        .size = .xy(1280, 720),
        .logicSize = .xy(640, 360),
        .scaleEnum = .fit,
    });
}
