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

const frogEnum = enum { idle, jump, fall };
const frogIdleFrames = zhu.graphics.framesX(4, .xy(35, 32), 0.3);
const frogJumpFrames: [1]zhu.graphics.Frame = .{
    .{ .area = .init(.xy(35, 32), .xy(35, 32)), .interval = 0.1 },
};
const frogFallFrames: [1]zhu.graphics.Frame = .{
    .{ .area = .init(.xy(70, 32), .xy(35, 32)), .interval = 0.1 },
};
var frogAnimations: zhu.graphics.EnumFrameAnimation(frogEnum) = undefined;
var frogState: frogEnum = .idle;

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

    const frogImage = getImage(@intFromEnum(map.ObjectEnum.frog));
    frogAnimations.set(.idle, .init(frogImage, &frogIdleFrames));
    frogAnimations.set(.jump, .init(frogImage, &frogJumpFrames));
    frogAnimations.set(.fall, .init(frogImage, &frogFallFrames));
}

pub fn update(delta: f32) void {
    gemAnimation.loopUpdate(delta);
    cherryAnimation.loopUpdate(delta);
    opossumAnimation.loopUpdate(delta);
    eagleAnimation.loopUpdate(delta);
    frogAnimations.getPtr(frogState).loopUpdate(delta);
}

pub fn draw() void {
    for (items) |item| {
        const image: ?zhu.graphics.Image = switch (item.type) {
            .gem => gemAnimation.currentImage(),
            .cherry => cherryAnimation.currentImage(),
            .opossum => opossumAnimation.currentImage(),
            .eagle => eagleAnimation.currentImage(),
            .frog => frogAnimations.get(frogState).currentImage(),
            else => null,
        };

        if (image) |img| batch.drawImage(img, item.position, .{});
    }
}
