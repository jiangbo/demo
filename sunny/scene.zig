const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;
const tiled = zhu.extend.tiled;

var isHelp = false;
var isDebug = false;
var vertexBuffer: []batch.Vertex = undefined;

const atlas: zhu.Atlas = @import("zon/atlas.zon");
const level1: tiled.Map = @import("zon/level1.zon");

pub fn init() void {
    // window.initText(@import("zon/font.zon"), 32);

    vertexBuffer = window.alloc(batch.Vertex, 5000);
    zhu.graphics.frameStats(true);
    batch.init(window.size, vertexBuffer);
    batch.whiteImage = zhu.graphics.imageId("white.png");
    zhu.assets.loadAtlas(atlas);
}

pub fn deinit() void {
    window.free(vertexBuffer);
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.H)) isHelp = !isHelp;
    if (window.isKeyRelease(.X)) isDebug = !isDebug;

    if (window.isKeyDown(.LEFT_ALT) and window.isKeyRelease(.ENTER)) {
        return window.toggleFullScreen();
    }
    _ = delta;
}

pub fn draw() void {
    batch.beginDraw(.black);

    for (level1.layers) |*layer| {
        if (layer.type != .image) continue;
        batch.draw(layer.image, .zero);
    }

    if (isHelp) drawHelpInfo() else if (isDebug) drawDebugInfo();
    batch.endDraw();
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关闭
    ;
    debutTextCount = zhu.text.computeTextCount(text);
    zhu.text.drawColor(text, .xy(10, 10), .green);
}

var debutTextCount: u32 = 0;
fn drawDebugInfo() void {
    var buffer: [1024]u8 = undefined;
    const format =
        \\后端：{s}
        \\帧率：{}
        \\平滑：{d:.2}
        \\帧时：{d:.2}
        \\用时：{d:.2}
        \\显存：{}
        \\常量：{}
        \\绘制：{}
        \\图片：{}
        \\文字：{}
        \\内存：{}
        \\鼠标：{d:.2}，{d:.2}
        \\相机：{d:.2}，{d:.2}
    ;

    const stats = zhu.graphics.queryFrameStats();
    const text = zhu.text.format(&buffer, format, .{
        @tagName(zhu.graphics.queryBackend()),
        window.frameRate,
        window.currentSmoothTime * 1000,
        window.frameDeltaPerSecond,
        window.usedDeltaPerSecond,
        stats.size_append_buffer + stats.size_update_buffer,
        stats.size_apply_uniforms,
        stats.num_draw,
        batch.imageDrawCount(),
        // Debug 信息本身的次数也应该统计进去
        zhu.graphics.textCount + debutTextCount,
        window.countingAllocator.used,
        window.mousePosition.x,
        window.mousePosition.y,
        zhu.camera.position.x,
        zhu.camera.position.y,
    });

    debutTextCount = zhu.text.computeTextCount(text);
    zhu.text.drawColor(text, .xy(10, 10), .green);
}
