const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;

const menu = @import("menu.zig");

const Background = struct {
    image: zhu.graphics.Image,
    offset: f32 = 0,

    fn update(self: *Background, delta: f32, speed: f32) void {
        self.offset -= speed * delta;
        if (self.offset > 0) self.offset -= self.image.area.size.x;
    }

    fn draw(self: *const Background, y: f32) void {
        // 填满 X 轴
        var x: f32 = self.offset;
        while (x < zhu.window.size.x) : (x += self.image.area.size.x) {
            zhu.batch.drawImage(self.image, .xy(@round(x), y), .{});
        }
    }
};

var far: Background = undefined;
var mid: Background = undefined;

pub fn init() void {
    far = .{ .image = zhu.getImage("textures/Layers/back.png") };
    mid = .{ .image = zhu.getImage("textures/Layers/middle.png") };

    zhu.audio.playMusic("assets/audio/platformer_level03_loop.ogg");
}

pub fn update(delta: f32) void {
    far.update(delta, 20);
    mid.update(delta, 60);

    _ = menu.update();
}

pub fn draw() void {
    far.draw(0);
    mid.draw(96);

    const titleImageId = zhu.imageId("textures/UI/title-screen.png");
    const pos = zhu.window.size.scale(0.5).addY(-50);
    batch.drawImageId(titleImageId, pos, .{
        .scale = .xy(2, 2),
        .anchor = .center,
    });

    menu.draw();
}
