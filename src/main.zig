const std = @import("std");
const zhu = @import("zhu");

const scene = @import("scene.zig");

var vertexBuffer: []zhu.batch.Vertex = undefined;
var commandBuffer: [128]zhu.batch.Command = undefined;
var soundBuffer: [20]zhu.audio.Sound = undefined;

pub fn init(allocator: zhu.Allocator) void {
    vertexBuffer = allocator.alloc(zhu.batch.Vertex, 4096);
    zhu.batch.init(vertexBuffer, &commandBuffer);
    zhu.audio.init(8000, &soundBuffer);
    zhu.assets.loadAtlas(@import("zon/atlas.zon"), .nearest);
    zhu.text.msdf.init(@import("zon/font.zon"));
    zhu.text.changeFontSize(18);

    zhu.batch.circleImage = zhu.getImage("circle.png").?;
    const size = zhu.batch.circleImage.size;
    const rect = zhu.Rect.init(.zero, size).centerScale(0.25);
    zhu.batch.whiteImage = zhu.batch.circleImage.sub(rect);

    scene.init();
}

pub fn frame(delta: f32) void {
    scene.update(delta);

    zhu.batch.beginDraw();
    zhu.batch.useTarget(.black, .{});
    scene.draw();
    zhu.batch.endDraw();
}

pub fn deinit(allocator: zhu.Allocator) void {
    scene.deinit();
    zhu.audio.deinit();
    allocator.free(vertexBuffer);
}

pub fn main(initInfo: std.process.Init) void {
    zhu.window.run(initInfo.io, initInfo.gpa, .{
        .title = "英雄救美",
        .size = .xy(640, 480),
        .scaleEnum = .fit,
    });
}

test "vector" {
    const value = zhu.Vector2.xy(1, 0);
    try std.testing.expectEqual(@as(f32, 1), value.x);
}
