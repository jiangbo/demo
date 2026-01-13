const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;

const background = zhu.graphics.imageId("UI/Textfield_01.png");

pub fn init() void {}

pub fn deinit() void {}

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn draw() void {
    // 标题
    const basicPos = zhu.Vector2.xy(320, 100); // 定位位置
    const size = zhu.window.logicSize.div(.xy(2, 3));

    camera.drawOption(background, basicPos, .{ .size = size });
    var pos = basicPos.addXY(150, 80);
    zhu.text.drawOption("幽 灵 逃 生", pos, .{ .size = 64 });

    camera.drawOption(background, basicPos.addXY(220, 285), .{
        .size = .xy(200, 60),
    });
    pos = basicPos.addXY(240, 300);
    zhu.text.drawText("最高分：", pos);
    zhu.text.drawNumber(77, pos.addX(125));
}
