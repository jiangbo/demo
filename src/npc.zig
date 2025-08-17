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
var npcPictures: [15][:0]const u8 = undefined;
var npcTextures: [npcPictures.len]gfx.Texture = undefined;
const frames: [2]gfx.Frame = .{
    .{ .area = .init(.init(0, 0), SIZE), .interval = 0.5 },
    .{ .area = .init(.init(32, 0), SIZE), .interval = 0.5 },
};

const State = struct {
    index: u8,
    position: math.Vector2,
    facing: gfx.FourDirection = .down,
    animation: Animation,
    timer: window.Timer = .init(5),
};

var npcBuffer: [10]State = undefined;
var npcArray: std.ArrayListUnmanaged(State) = undefined;

pub fn init() void {
    for (&npcTextures, &npcPictures, 1..) |*texture, *picture, i| {
        const path = std.fmt.allocPrintZ(window.allocator, //
            "assets/pic/npc{:02}.png", .{i}) catch unreachable;
        picture.* = path;
        texture.* = gfx.loadTexture(path, .init(64, 128));
    }
    npcArray = .initBuffer(&npcBuffer);
}

pub fn deinit() void {
    for (&npcPictures) |value| window.allocator.free(value);
}

pub fn enter() void {
    npcArray.clearRetainingCapacity();

    for (map.current.npcs) |id| {
        npcArray.appendAssumeCapacity(.{
            .index = id,
            .facing = .random(),
            .position = .init(zon[id].x, zon[id].y),
            .animation = buildAnimation(npcTextures[zon[id].picture]),
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

        // NPC 和地图的碰撞检测，只检测一半大小
        const offset = math.Vector2.init(8, 16);

        const pos = npc.position.add(offset);
        const area = math.Rect.init(pos, SIZE.scale(0.5));
        var newPosition = map.walkTo(area, velocity);
        // if (newPosition.approxEqual(pos)) {
        //     // 坐标相等，表示没有移动，撞墙了。
        //     const old = npc.facing;
        //     while (old == npc.facing) npc.facing = .random();
        //     npc.timer.reset();
        //     return;
        // }

        // 检测和角色的碰撞
        newPosition = newPosition.sub(offset);
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

pub fn talk(collider: math.Rect, facing: math.FourDirection) ?u8 {
    for (npcArray.items) |*npc| {
        const npcCollider = math.Rect.init(npc.position, SIZE);
        if (collider.intersect(npcCollider)) {
            // 将 NPC 的面向调整到角色的反方向
            npc.facing = facing.opposite();
            return zon[npc.index].talk;
        }
    }
    return null;
}

pub fn draw() void {
    for (npcArray.items) |npc| {
        const animation = npc.animation.getPtrConst(npc.facing);
        camera.draw(animation.currentTexture(), npc.position);
    }
}

pub fn drawTalk(actor: u8) void {

    // 头像
    const texture = npcTextures[zon[actor].picture];
    camera.draw(texture.subTexture(.init(.zero, SIZE)), .init(40, 400));

    // 名字
    const name = zon[actor].name;
    const nameColor = gfx.color(1, 1, 0, 1);
    camera.drawColorText(name, .init(25, 445), nameColor);
}

pub const Character = struct {
    enemy: bool = false,
    talk: u8 = 0,
    name: []const u8 = &.{},
    x: f32 = 0,
    y: f32 = 0,
    picture: u8 = 0,
    facing: gfx.FourDirection = .down,
    // stats: u8,
    // level: u8,
    // exp: u32,
    // lift: u16,
    // maxLift: u16,
    // attack: u16,
    // defend: u16,
    speed: f32 = 20,
    // goods: [1]u32,
    // money: u32,
};
