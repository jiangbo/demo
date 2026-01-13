const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;

const background = zhu.graphics.imageId("UI/Textfield_01.png");

pub fn init() void {}

pub fn deinit() void {}

var time: f32 = 0;
pub fn update(delta: f32) void {
    time += delta;
}

pub fn draw() void {

    // 边框
    var size = zhu.window.logicSize.sub(.xy(60, 60));
    camera.drawRectBorder(.init(.xy(30, 30), size), 10, .{
        .r = zhu.sinInt(u8, time * 0.9, 100, 255),
        .g = zhu.sinInt(u8, time * 0.8, 100, 255),
        .b = zhu.sinInt(u8, time * 0.7, 100, 255),
        .a = 255,
    });

    // 标题
    const basicPos = zhu.Vector2.xy(320, 100); // 定位位置
    size = zhu.window.logicSize.div(.xy(2, 3));

    // 先绘制图片，再绘制文字，减少批量绘制次数
    camera.drawOption(background, basicPos, .{ .size = size });
    camera.drawOption(background, basicPos.addXY(220, 285), .{
        .size = .xy(200, 60),
    });

    var pos = basicPos.addXY(150, 80);
    zhu.text.drawOption("幽 灵 逃 生", pos, .{ .size = 64 });

    pos = basicPos.addXY(240, 300);
    zhu.text.drawText("最高分：", pos);
    zhu.text.drawNumber(77, pos.addX(125));
}
