const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;

const player = @import("player.zig");
const npc = @import("npc.zig");

const Talk = struct {
    actor: u8 = 0,
    content: []const u8 = &.{},
    format: enum { none, int, str } = .none,
    next: usize = 1, // 0：表示结束，1：表示下一条
};
const zon: []const Talk = @import("zon/talk.zon");
var talkTexture: gfx.Texture = undefined;

pub var talkNumber: usize = 0;
pub var talkText: [50]u8 = undefined;

var buffer: [256]u8 = undefined;
var bufferIndex: usize = 0;

pub fn init() void {
    talkTexture = gfx.loadTexture("assets/pic/talkbar.png", .init(640, 96));
}

pub fn update(talkId: usize) usize {
    if (!window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) return talkId;

    bufferIndex = 0;
    return zon[talkId].next;
}

pub fn draw(talkId: usize) void {
    camera.draw(talkTexture, .init(0, 384));

    const talk = zon[talkId];
    if (talk.actor == 0)
        player.drawTalk()
    else if (talk.actor < 200)
        npc.drawTalk(talk.actor);

    var content = talk.content;

    if (talk.format == .int) {
        content = if (bufferIndex == 0)
            formatInt(content)
        else
            buffer[0..bufferIndex];
    } else if (talk.format == .str) {
        content = if (bufferIndex == 0)
            formatStr(content)
        else
            buffer[0..bufferIndex];
    }

    camera.drawTextOptions(content, .{
        .color = .{ .w = 1 },
        .position = .init(123, 403),
        .width = 593,
    });
    camera.drawTextOptions(content, .{
        .color = .one,
        .position = .init(120, 400),
        .width = 590,
    });
}

fn formatInt(content: []const u8) []const u8 {
    const text = zhu.format(&talkText, comptime "{d}", .{talkNumber});
    talkNumber = text.len;
    return formatStr(content);
}

fn formatStr(content: []const u8) []const u8 {
    const text = talkText[0..talkNumber];
    const times = std.mem.replace(u8, content, "{}", text, &buffer);
    std.debug.assert(times == 1);

    bufferIndex = content.len - 2 + text.len;
    return buffer[0..bufferIndex];
}
