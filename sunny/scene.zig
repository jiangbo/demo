const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const batch = zhu.batch;
const tiled = zhu.extend.tiled;

const map = @import("map.zig");
const player = @import("player.zig");
const object = @import("object.zig");

var help = false;
var debug = false;

pub fn init() void {
    map.init();

    for (map.objects.items, 0..) |obj, index| {
        if (obj.type != .player) continue;
        player.init(obj.position, obj.size, obj.tileObject.?);
        _ = map.objects.swapRemove(index);
        break;
    }
    object.init(map.objects.items);
}

pub fn deinit() void {
    map.deinit();
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.H)) help = !help;
    if (window.isKeyRelease(.X)) debug = !debug;

    if (window.isKeyDown(.LEFT_ALT) and window.isKeyRelease(.ENTER)) {
        return window.toggleFullScreen();
    }

    const distance: f32 = std.math.round(300 * delta);
    zhu.camera.control(distance);

    player.update(delta);
    object.update(delta);
}

pub fn draw() void {
    zhu.batch.beginDraw(.black);
    defer zhu.batch.endDraw();

    map.draw();
    object.draw();
    player.draw();

    if (help) drawHelpInfo() else if (debug) window.drawDebugInfo();
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
