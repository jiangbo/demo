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
    next: usize = 0,
};
const talks: []const Talk = @import("zon/talk.zon");
var talkTexture: gfx.Texture = undefined;

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

    player.update(delta);
}

fn updateTalk(talkId: usize) void {
    if (!confirm()) return;

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

    camera.drawColorText(talk.content, .init(123, 403), .{ .w = 1 });
    camera.drawColorText(talk.content, .init(120, 400), .one);
}
