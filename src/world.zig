const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;

const player = @import("player.zig");
const map = @import("map.zig");

const Status = union(enum) { normal, talk: usize };
var status: Status = .normal;

const Talk = struct {
    actor: u8 = 0,
    content: []const u8,
    format: enum { none, int } = .none,
    next: usize = 0,
};
const talks: []const Talk = @import("zon/talk.zon");
var talkTexture: gfx.Texture = undefined;
var talkNumber: usize = 0;
var buffer: [256]u8 = undefined;
var bufferIndex: usize = 0;

pub fn init() void {
    talkTexture = gfx.loadTexture("assets/pic/talkbar.png", .init(640, 96));
    // status = .{ .talk = 1 };
    map.init();
    player.init();

    // window.playMusic("assets/voc/back.ogg");
}

pub fn update(delta: f32) void {
    switch (status) {
        .normal => {},
        .talk => |talkId| return updateTalk(talkId),
    }

    // 角色移动和碰撞检测
    const toPosition = player.toMove(delta);
    if (toPosition) |position| {
        if (map.canWalk(position.addXY(-8, -12)) and
            map.canWalk(position.addXY(-8, 2)) and
            map.canWalk(position.addXY(8, -12)) and
            map.canWalk(position.addXY(8, 2)))
            player.position = position;
    }

    // 交互检测
    if (confirm()) {
        const object = map.talk(player.position, player.facing());
        if (object != 0) handleObject(object);
    }

    player.update(delta);
}

fn handleObject(object: u16) void {
    if (object == 301) {
        const gold = window.random().intRangeLessThanBiased(u8, 10, 100);
        player.money += gold;
        status = .{ .talk = 3 };
        talkNumber = gold;
    }
}

fn updateTalk(talkId: usize) void {
    if (!confirm()) return;

    bufferIndex = 0;
    const next = talks[talkId].next;
    status = if (next == 0) .normal else .{ .talk = next };
}

fn confirm() bool {
    return window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER });
}

pub fn enter() void {}

pub fn exit() void {}

pub fn render() void {
    map.render();
    player.render();

    switch (status) {
        .normal => {},
        .talk => |talkId| renderTalk(talkId),
    }
}

fn renderTalk(talkId: usize) void {
    camera.draw(talkTexture, .init(0, 384));

    const talk = talks[talkId];
    if (talk.actor == 0) player.renderTalk();

    var content = talk.content;
    if (talk.format == .int) {
        content = if (bufferIndex == 0)
            formatInt(content)
        else
            buffer[0..bufferIndex];
    }

    camera.drawColorText(content, .init(123, 403), .{ .w = 1 });
    camera.drawColorText(content, .init(120, 400), .one);
}

fn formatInt(content: []const u8) []const u8 {
    const index = std.fmt.bufPrint(buffer[240..], "{d}", .{talkNumber});
    const text = index catch unreachable;

    const times = std.mem.replace(u8, content, "{}", text, &buffer);
    std.debug.assert(times == 1);

    bufferIndex = content.len - 2 + text.len;
    return buffer[0..bufferIndex];
}
