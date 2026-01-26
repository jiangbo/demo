const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;

const map = @import("map.zig");
const getImage = zhu.assets.getImage;

const gemFrames = zhu.graphics.framesX(5, .xy(15, 13), 0.2);
const cherryFrames = zhu.graphics.loopFramesX(5, .xy(21, 21), 0.2);
const opossumFrames = zhu.graphics.framesX(6, .xy(36, 28), 0.1);
const eagleFrames = zhu.graphics.framesX(4, .xy(40, 41), 0.15);

var gemAnimation: zhu.graphics.FrameAnimation = undefined;
var cherryAnimation: zhu.graphics.FrameAnimation = undefined;
var opossumAnimation: zhu.graphics.FrameAnimation = undefined;
var eagleAnimation: zhu.graphics.FrameAnimation = undefined;

var items: []map.Object = undefined;

pub fn init(objects: []map.Object) void {
    items = objects;

    const gemImage = getImage(@intFromEnum(map.ObjectEnum.gem));
    gemAnimation = .init(gemImage, &gemFrames);

    const cherryImage = getImage(@intFromEnum(map.ObjectEnum.cherry));
    cherryAnimation = .init(cherryImage, &cherryFrames);

    const opossumImage = getImage(@intFromEnum(map.ObjectEnum.opossum));
    opossumAnimation = .init(opossumImage, &opossumFrames);

    const eagleImage = getImage(@intFromEnum(map.ObjectEnum.eagle));
    eagleAnimation = .init(eagleImage, &eagleFrames);
}

pub fn update(delta: f32) void {
    gemAnimation.loopUpdate(delta);
    cherryAnimation.loopUpdate(delta);
    opossumAnimation.loopUpdate(delta);
    eagleAnimation.loopUpdate(delta);
}

pub fn draw() void {
    for (items) |item| {
        const image: ?zhu.graphics.Image = switch (item.type) {
            .gem => gemAnimation.currentImage(),
            .cherry => cherryAnimation.currentImage(),
            .opossum => opossumAnimation.currentImage(),
            .eagle => eagleAnimation.currentImage(),
            else => null,
        };

        if (image) |img| {
            batch.drawImage(img, item.position, .{});
        }
    }
}
