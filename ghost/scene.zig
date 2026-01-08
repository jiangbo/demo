const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const graphics = zhu.graphics;
const camera = zhu.camera;

var isHelp = false;
var isDebug = false;
var vertexBuffer: []graphics.Vertex = undefined;

const atlas: graphics.Atlas = @import("zon/atlas.zon");

pub fn init() void {
    window.initText(@import("zon/font.zon"), 24);

    vertexBuffer = window.alloc(graphics.Vertex, 5000);
    graphics.frameStats(true);
    graphics.initWithWhiteTexture(window.logicSize, vertexBuffer);

    graphics.loadAtlas(atlas);
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.H)) isHelp = !isHelp;
    if (window.isKeyRelease(.X)) isDebug = !isDebug;

    if (window.isKeyDown(.LEFT_ALT) and window.isKeyRelease(.ENTER)) {
        return window.toggleFullScreen();
    }

    const speed: f32 = std.math.round(400 * delta);
    if (window.isKeyDown(.UP)) camera.position.y -= speed;
    if (window.isKeyDown(.DOWN)) camera.position.y += speed;
    if (window.isKeyDown(.LEFT)) camera.position.x -= speed;
    if (window.isKeyDown(.RIGHT)) camera.position.x += speed;
}

pub fn draw() void {
    camera.beginDraw(.{});
    defer camera.endDraw();
    window.keepAspectRatio();

    const gridColor = graphics.rgb(0.5, 0.5, 0.5);
    const area = zhu.Rect.init(.zero, window.logicSize.scale(3));
    drawGrid(area, 80, gridColor);
    camera.drawRectBorder(area, 10, .white);

    camera.mode = .local;
    defer camera.mode = .world;

    if (isHelp) drawHelpInfo() else if (isDebug) drawDebugInfo();
}

fn drawGrid(area: zhu.Rect, width: f32, lineColor: zhu.Color) void {
    const max = area.max();
    const color = camera.LineOption{ .color = lineColor };

    var min = area.min;
    while (min.x < max.x) : (min.x += width) {
        camera.drawAxisLine(min, .init(min.x, max.y), color);
    }

    min = area.min;
    while (min.y < max.y) : (min.y += width) {
        camera.drawAxisLine(min, .init(max.x, min.y), color);
    }
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关闭
    ;
    debutTextCount = zhu.text.computeTextCount(text);
    zhu.text.drawColor(text, .init(10, 10), .green);
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

    const stats = graphics.queryFrameStats();
    const text = zhu.format(&buffer, format, .{
        @tagName(graphics.queryBackend()),
        window.frameRate,
        window.currentSmoothTime * 1000,
        window.frameDeltaPerSecond,
        window.usedDeltaPerSecond,
        stats.size_append_buffer + stats.size_update_buffer,
        stats.size_apply_uniforms,
        stats.num_draw,
        camera.imageDrawCount(),
        // Debug 信息本身的次数也应该统计进去
        camera.textDrawCount() + debutTextCount,
        window.countingAllocator.used,
        window.mousePosition.x,
        window.mousePosition.y,
        camera.position.x,
        camera.position.y,
    });

    debutTextCount = zhu.text.computeTextCount(text);
    zhu.text.drawColor(text, .init(10, 10), .green);
}

pub fn deinit() void {
    window.free(vertexBuffer);
}
