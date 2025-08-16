const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

const SIZE: math.Vector2 = .init(32, 32);
const map = @import("map.zig");
const player = @import("player.zig");

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
    timer: window.Timer = .init(5),
};

var buffer: [10]Info = undefined;
var npcArray: std.ArrayListUnmanaged(Info) = undefined;

pub fn init() void {
    for (imageNames, &npcTextures) |name, *texture| {
        texture.* = gfx.loadTexture(name, .init(64, 128));
    }
    npcArray = .initBuffer(&buffer);
}

pub fn enter() void {
    npcArray.clearRetainingCapacity();

    for (map.current.npcs) |id| {
        npcArray.appendAssumeCapacity(.{
            .index = id,
            .position = .init(zon[id].x, zon[id].y),
            .animation = buildAnimation(npcTextures[id]),
        });
    }
}

fn buildAnimation(texture: gfx.Texture) Animation {
    var animation = Animation.initUndefined();

    var tex = texture.subTexture(.init(.zero, .init(64, SIZE.x)));
    animation.set(.down, gfx.FrameAnimation.init(tex, &frames));
    tex = texture.subTexture(tex.area.move(.init(0, SIZE.x)));
    animation.set(.left, gfx.FrameAnimation.init(tex, &frames));
    tex = texture.subTexture(tex.area.move(.init(0, SIZE.x)));
    animation.set(.up, gfx.FrameAnimation.init(tex, &frames));
    tex = texture.subTexture(tex.area.move(.init(0, SIZE.x)));
    animation.set(.right, gfx.FrameAnimation.init(tex, &frames));

    return animation;
}

pub fn update(delta: f32) void {
    for (npcArray.items) |*npc| {
        if (npc.timer.isFinishedAfterUpdate(delta)) {
            npc.facing = .random();
            npc.timer.reset();
        }

        npc.animation.getPtr(npc.facing).update(delta);
        const speed = zon[npc.index].speed * delta;
        const velocity: math.Vector2 = switch (npc.facing) {
            .down => .init(0, speed),
            .left => .init(-speed, 0),
            .up => .init(0, -speed),
            .right => .init(speed, 0),
        };

        const area = math.Rect.init(npc.position, SIZE);
        const newPosition = map.walkTo(area, velocity);
        if (newPosition.approxEqual(npc.position)) {
            const old = npc.facing;
            while (old == npc.facing) npc.facing = .random();
            npc.timer.reset();
            return;
        }

        // 检测和角色的碰撞
        const collider = math.Rect.init(newPosition, SIZE);
        if (!collider.intersect(player.collider())) {
            npc.position = newPosition;
        }
    }
}

pub fn isCollision(collider: math.Rect) bool {
    for (npcArray.items) |npc| {
        const npcCollider = math.Rect.init(npc.position, SIZE);
        if (collider.intersect(npcCollider)) return true;
    }
    return false;
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
    speed: f32,
    goods: [1]u32,
    money: u32,
};
