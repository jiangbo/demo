const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;
const math = @import("zhu").math;

const FrameAnimation = gfx.FixedFrameAnimation(3, 0.1);
const Animation = std.EnumArray(math.FourDirection, FrameAnimation);

var playerTexture: gfx.Texture = undefined;
pub var playerAnimation: Animation = undefined;
pub var playerDirection: math.FourDirection = .up;
pub var playerPosition: math.Vector = .init(180, 164);

pub fn init() void {
    playerTexture = gfx.loadTexture("assets/pic/player.png", .init(96, 192));
    playerAnimation = createAnimation("assets/pic/player.png");
}

fn createAnimation(path: [:0]const u8) Animation {
    var animation = Animation.initUndefined();

    const texture = gfx.loadTexture(path, .init(96, 192));
    var tex = texture.subTexture(.init(.zero, .init(96, 48)));
    animation.set(.down, FrameAnimation.init(tex));

    tex = texture.subTexture(.init(.init(0, 48), .init(96, 48)));
    animation.set(.left, FrameAnimation.init(tex));

    tex = texture.subTexture(.init(.init(0, 96), .init(96, 48)));
    animation.set(.right, FrameAnimation.init(tex));

    tex = texture.subTexture(.init(.init(0, 144), .init(96, 48)));
    animation.set(.up, FrameAnimation.init(tex));
    return animation;
}
