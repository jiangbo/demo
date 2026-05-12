const zhu = @import("zhu");

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn draw() void {
    drawRect(.init(.xy(0, 0), .xy(320, 180)), .rgb(0.26, 0.38, 0.31));
    drawRect(.init(.xy(0, 128), .xy(320, 52)), .rgb(0.18, 0.42, 0.23));
    drawRect(.init(.xy(120, 72), .xy(80, 56)), .rgb(0.66, 0.43, 0.25));
    drawRect(.init(.xy(112, 96), .xy(96, 12)), .rgb(0.43, 0.23, 0.16));
    drawRect(.init(.xy(152, 104), .xy(16, 24)), .rgb(0.22, 0.15, 0.11));
    drawRect(.init(.xy(144, 52), .xy(32, 24)), .rgb(0.80, 0.76, 0.55));
    drawRect(.init(.xy(96, 128), .xy(128, 10)), .rgb(0.36, 0.25, 0.15));
}

fn drawRect(area: zhu.Rect, color: zhu.Color) void {
    zhu.batch.drawImage(zhu.batch.whiteImage, area.min, .{
        .size = area.size,
        .color = color,
    });
}
