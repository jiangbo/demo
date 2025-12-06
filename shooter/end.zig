const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;
const text = zhu.text;

const player = @import("player.zig");

var isTyping: bool = true;

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn draw() void {
    var buffer: [255]u8 = undefined;
    const score = zhu.format(&buffer, "你的得分是：{}", .{player.score});
    text.drawCenter(score, 0.1, .{ .spacing = 2 });

    text.drawCenter("GAME OVER", 0.35, .{ .size = 72, .spacing = 5 });

    const typing = "请输入你的名字，按回车键确认：";
    text.drawCenter(typing, 0.6, .{ .spacing = 2 });
}
