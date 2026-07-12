const std = @import("std");
const zhu = @import("zhu");

const math = zhu.math;

const SIZE: zhu.Vector2 = .xy(32, 32);
const map = @import("map.zig");
const player = @import("player.zig");
const Direction = @import("context.zig").Direction;

const Animation = zhu.EnumAnimation(Direction);
pub const zon: []const Character = @import("zon/npc.zon");
var npcPaths: [15][:0]const u8 = blk: {
    var list: [15][:0]const u8 = undefined;
    for (&list, 1..) |*value, i| {
        value.* = std.fmt.comptimePrint("npc{:02}.png", .{i});
    }
    break :blk list;
};
var npcTextures: [npcPaths.len]zhu.Image = undefined;
const frames: [2]zhu.graphics.Frame = .{
    .{ .offset = .xy(0, 0), .duration = 0.5 },
    .{ .offset = .xy(32, 0), .duration = 0.5 },
};
pub var dead: std.StaticBitSet(64) = .initEmpty();

const State = struct {
    index: u8,
    position: math.Vector2,
    facing: Direction = .down,
    animation: Animation,
    timer: zhu.Timer,
};

var npcBuffer: [12]State = undefined;
var npcArray: std.ArrayListUnmanaged(State) = undefined;

pub fn init() void {
    for (&npcTextures, &npcPaths) |*texture, path| {
        texture.* = zhu.assets.getImage(zhu.assets.id(path)).?;
    }
    npcArray = .initBuffer(&npcBuffer);
}

pub fn enter() void {
    npcArray.clearRetainingCapacity();

    for (map.current.npcs) |id| {
        if (dead.isSet(id)) continue;
        const stop = zon[id].speed == 0;
        if (zon[id].progress < player.progress) continue;
        npcArray.appendAssumeCapacity(.{
            .index = id,
            .facing = if (stop) zon[id].facing else .random(),
            .position = .xy(zon[id].x, zon[id].y),
            .animation = buildAnimation(npcTextures[zon[id].picture]),
            .timer = .init(zhu.random.float(3, 5)),
        });
    }
}

fn buildAnimation(texture: zhu.Image) Animation {
    var animation = Animation.initUndefined();
    const rowSize = zhu.Vector2.xy(64, 32);
    animation.set(.down, zhu.Animation.init(
        texture.sub(.init(.xy(0, 0), rowSize)),
        SIZE,
        &frames,
    ));
    animation.set(.left, zhu.Animation.init(
        texture.sub(.init(.xy(0, 32), rowSize)),
        SIZE,
        &frames,
    ));
    animation.set(.up, zhu.Animation.init(
        texture.sub(.init(.xy(0, 64), rowSize)),
        SIZE,
        &frames,
    ));
    animation.set(.right, zhu.Animation.init(
        texture.sub(.init(.xy(0, 96), rowSize)),
        SIZE,
        &frames,
    ));

    return animation;
}

pub fn update(delta: f32) void {
    for (npcArray.items) |*npc| {
        const speed = zon[npc.index].speed * delta;
        if (npc.timer.updateFinished(delta) and speed > 0) {
            npc.facing = .random();
            npc.timer = .init(zhu.random.float(3, 5));
        }

        _ = npc.animation.getPtr(npc.facing).update(delta);
        const velocity: math.Vector2 = switch (npc.facing) {
            .down => .xy(0, speed),
            .left => .xy(-speed, 0),
            .up => .xy(0, -speed),
            .right => .xy(speed, 0),
        };

        // NPC 和地图的碰撞检测，只检测一半大小
        const offset = math.Vector2.xy(8, 16);

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

pub fn death(index: u16) void {
    dead.set(index);
    for (npcArray.items, 0..) |npc, i| {
        if (npc.index == index) {
            _ = npcArray.swapRemove(i);
            return;
        }
    }
}

pub fn talk(collider: math.Rect, facing: Direction) ?u8 {
    for (npcArray.items) |*npc| {
        if (zon[npc.index].enemy) continue;

        const npcCollider = math.Rect.init(npc.position, SIZE);
        if (collider.intersect(npcCollider)) {
            // 将 NPC 的面向调整到角色的反方向
            npc.facing = facing.opposite();
            const index: u8 = if (player.progress > 4) 1 else 0;
            return zon[npc.index].talks[index];
        }
    }
    return null;
}

pub fn battle(collider: math.Rect, facing: Direction) ?u8 {
    for (npcArray.items) |*npc| {
        if (!zon[npc.index].enemy) continue;
        // 战斗的时候，将敌人的碰撞范围扩大
        const pos = npc.position.sub(SIZE.scale(0.25));
        const area = math.Rect.init(pos, SIZE.scale(1.5));
        if (collider.intersect(area)) {
            // 将 NPC 的面向调整到角色的反方向
            npc.facing = facing.opposite();
            return npc.index;
        }
    }
    return null;
}

pub fn draw() void {
    for (npcArray.items) |npc| {
        const current = npc.animation.getPtrConst(npc.facing);
        zhu.batch.drawImage(current.subImage(), npc.position, .{});
    }
}

pub fn drawTalk(actor: u8) void {
    zhu.batch.drawImage(photo(actor), .xy(40, 400), .{});

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(zon[actor].name, .xy(25, 445), .{
        .color = .yellow,
    });
}

pub fn photo(npcIndex: u16) zhu.Image {
    const texture = npcTextures[zon[npcIndex].picture];
    return texture.sub(.init(.zero, SIZE));
}

pub fn battleTexture(npcIndex: u16) zhu.Image {
    const texture = npcTextures[zon[npcIndex].picture];
    return texture.sub(.init(.xy(0, SIZE.x), SIZE));
}

pub const Character = struct {
    enemy: bool = false,
    talks: []const u8 = &.{},
    name: []const u8 = &.{},
    x: f32 = 0,
    y: f32 = 0,
    picture: u8 = 0,
    facing: Direction = .down,
    // stats: u8,
    level: u16 = 1,
    // exp: u32,
    health: u16 = 0,
    // maxLift: u16,
    attack: u16 = 0,
    defend: u16 = 0,
    speed: f32 = 0,
    goods: []const u8 = &.{},
    money: u16 = 0,
    progress: u8 = 0xFF,
    escape: u8 = 50, // 逃跑成功率
};
