const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

const Animation = std.EnumArray(math.FourDirection, gfx.FrameAnimation);
const zon: []const Character = @import("zon/npc.zon");
const imageNames: []const [:0]const u8 = @import("zon/npcTex.zon");
var npcTextures: [imageNames.len]gfx.Texture = undefined;
const frames: [2]gfx.Frame = .{
    .{ .area = .init(.init(0, 0), .init(32, 32)), .interval = 0.5 },
    .{ .area = .init(.init(32, 0), .init(32, 32)), .interval = 0.5 },
};

const Info = struct {
    index: u8,
    position: math.Vector2,
    facing: gfx.FourDirection = .down,
    animation: Animation,
};

var buffer: [10]Info = undefined;
var npcArray: std.ArrayListUnmanaged(Info) = undefined;

pub fn init() void {
    for (imageNames, &npcTextures) |name, *texture| {
        texture.* = gfx.loadTexture(name, .init(64, 128));
    }
    npcArray = .initBuffer(&buffer);
}

pub fn enter(npcIds: []const u8) void {
    npcArray.clearRetainingCapacity();

    for (npcIds) |id| {
        npcArray.appendAssumeCapacity(.{
            .index = id,
            .position = .init(zon[id].x, zon[id].y),
            .animation = buildAnimation(npcTextures[id]),
        });
    }
}

fn buildAnimation(texture: gfx.Texture) Animation {
    var animation = Animation.initUndefined();

    var tex = texture.subTexture(.init(.zero, .init(64, 32)));
    animation.set(.down, gfx.FrameAnimation.init(tex, &frames));
    tex = texture.subTexture(tex.area.move(.init(0, 32)));
    animation.set(.left, gfx.FrameAnimation.init(tex, &frames));
    tex = texture.subTexture(tex.area.move(.init(0, 32)));
    animation.set(.right, gfx.FrameAnimation.init(tex, &frames));
    tex = texture.subTexture(tex.area.move(.init(0, 32)));
    animation.set(.up, gfx.FrameAnimation.init(tex, &frames));

    return animation;
}

pub fn update(delta: f32) void {
    for (npcArray.items) |*npc| {
        // if (zhu.randU8(0, 100) > 80) {
        //     npc.facing = zhu.randEnum(gfx.FourDirection);
        // }
        npc.animation.getPtr(npc.facing).update(delta);
    }
}

pub fn draw() void {
    for (npcArray.items) |npc| {
        const animation = npc.animation.getPtrConst(npc.facing);
        camera.draw(animation.currentTexture(), npc.position);
    }
}

pub const Character = struct {
    id: u32,
    pic: u8,
    enemy: bool,
    talkNum: u8,
    active: bool,
    show: bool,
    name: []const u8,
    width: u16,
    height: u16,
    x: f32,
    y: f32,
    oldX: u16,
    oldY: u16,
    facing: gfx.FourDirection = .down,
    stats: u8,
    level: u8,
    exp: u32,
    lift: u16,
    maxLift: u16,
    attack: u16,
    defend: u16,
    speed: u8,
    goods: [1]u32,
    money: u32,
};
