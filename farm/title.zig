const zhu = @import("zhu");

pub fn update(delta: f32) void {
    _ = delta;
}

pub fn draw() void {
    drawRect(.init(.xy(0, 0), .xy(640, 360)), .rgb(0.26, 0.38, 0.31));
    drawRect(.init(.xy(0, 256), .xy(640, 104)), .rgb(0.18, 0.42, 0.23));
    drawRect(.init(.xy(240, 144), .xy(160, 112)), .rgb(0.66, 0.43, 0.25));
    drawRect(.init(.xy(224, 192), .xy(192, 24)), .rgb(0.43, 0.23, 0.16));
    drawRect(.init(.xy(304, 208), .xy(32, 48)), .rgb(0.22, 0.15, 0.11));
    drawRect(.init(.xy(288, 104), .xy(64, 48)), .rgb(0.80, 0.76, 0.55));
    drawRect(.init(.xy(192, 256), .xy(256, 20)), .rgb(0.36, 0.25, 0.15));
}

fn drawRect(area: zhu.Rect, color: zhu.Color) void {
    zhu.batch.drawImage(zhu.batch.whiteImage, area.min, .{
        .size = area.size,
        .color = color,
    });
}
