const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;

const level = @import("level.zig");

var help = false;
var debug = false;
var vertexBuffer: []zhu.batch.Vertex = undefined;

const atlas: zhu.Atlas = @import("zon/atlas.zon");

pub fn init() void {
    // window.initText(@import("zon/font.zon"), 32);

    vertexBuffer = window.alloc(zhu.batch.Vertex, 5000);
    zhu.graphics.frameStats(true);
    zhu.batch.init(window.size, vertexBuffer);
    zhu.batch.whiteImage = zhu.graphics.imageId("white.png");
    zhu.assets.loadAtlas(atlas);

    level.init();
}

pub fn deinit() void {
    level.deinit();
    window.free(vertexBuffer);
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.H)) help = !help;
    if (window.isKeyRelease(.X)) debug = !debug;

    if (window.isKeyDown(.LEFT_ALT) and window.isKeyRelease(.ENTER)) {
        return window.toggleFullScreen();
    }

    const distance: f32 = std.math.round(300 * delta);
    zhu.camera.control(distance);
}

pub fn draw() void {
    zhu.batch.beginDraw(.black);

    level.draw();

    if (help) drawHelpInfo() else if (debug) window.drawDebugInfo();
    zhu.batch.endDraw();
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关闭
    ;
    zhu.text.drawColor(text, .xy(10, 10), .green);
}
