const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;
const math = @import("zhu").math;

const map = @import("map.zig");

const FrameAnimation = gfx.FixedFrameAnimation(3, 0.15);
const Animation = std.EnumArray(math.FourDirection, FrameAnimation);

const name = "小飞刀";
const speed = 100;
var texture: gfx.Texture = undefined;
var animation: Animation = undefined;

var moving: bool = false;
var direction: math.Vector = .zero;
var offset: math.Vector = .zero;
var position: math.Vector = .init(180, 164);

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/player.png", .init(96, 192));

    offset = math.Vector{ .x = -16, .y = -45 };
    animation = Animation.initUndefined();

    var tex = texture.subTexture(.init(.zero, .init(96, 48)));
    animation.set(.down, FrameAnimation.init(tex));

    tex = texture.subTexture(tex.area.move(.init(0, 48)));
    animation.set(.left, FrameAnimation.init(tex));

    tex = texture.subTexture(tex.area.move(.init(0, 48)));
    animation.set(.right, FrameAnimation.init(tex));

    tex = texture.subTexture(tex.area.move(.init(0, 48)));
    animation.set(.up, FrameAnimation.init(tex));
}

pub fn update(delta: f32) void {
    move(delta);

    if (moving) animation.getPtr(facing()).update(delta);
}

fn move(delta: f32) void {
    var dir = math.Vector.zero;
    if (window.isAnyKeyDown(&.{ .UP, .W })) dir.y -= 1;
    if (window.isAnyKeyDown(&.{ .DOWN, .S })) dir.y += 1;
    if (window.isAnyKeyDown(&.{ .LEFT, .A })) dir.x -= 1;
    if (window.isAnyKeyDown(&.{ .RIGHT, .D })) dir.x += 1;

    if (dir.approxEqual(.zero)) {
        moving = false;
    } else {
        moving = true;
        direction = dir.normalize().scale(speed);
        const pos = position.add(direction.scale(delta));
        if (map.canWalk(pos.addXY(-8, -12)) and
            map.canWalk(pos.addXY(-8, 2)) and
            map.canWalk(pos.addXY(8, -12)) and
            map.canWalk(pos.addXY(8, 2)))
            position = pos;
    }
}

pub fn render() void {
    const current = animation.get(facing());
    camera.draw(current.currentTexture(), position.add(offset));
}

fn facing() math.FourDirection {
    if (@abs(direction.x) > @abs(direction.y))
        return if (direction.x < 0) .left else .right
    else
        return if (direction.y < 0) .up else .down;
}

pub fn renderTalk() void {

    // 头像
    const down = animation.get(.down);
    const tex = down.texture.subTexture(down.frames[0]);
    camera.draw(tex, .init(30, 396));

    // 名字
    const nameColor = gfx.color(1, 1, 0, 1);
    camera.drawColorText(name, .init(18, 445), nameColor);
}
