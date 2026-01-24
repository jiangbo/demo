const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;

const map = @import("map.zig");
const getImage = zhu.assets.getImage;

const gemFrames = zhu.graphics.loopFramesX(5, .xy(15, 13), 0.2);
var gemAnimation: zhu.graphics.FrameAnimation = undefined;

var items: []map.Object = undefined;

pub fn init(objects: []map.Object) void {
    items = objects;

    const gemImage = getImage(@intFromEnum(map.ObjectEnum.gem));
    gemAnimation = .init(gemImage, &gemFrames);
}

pub fn update(delta: f32) void {
    gemAnimation.loopUpdate(delta);
}

pub fn draw() void {
    for (items) |item| {
        const image: ?zhu.graphics.Image = switch (item.type) {
            .gem => gemAnimation.currentImage(),
            else => null,
        };

        if (image) |img| {
            batch.drawImage(img, item.position, .{});
        }
    }
}
