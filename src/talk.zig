const std = @import("std");

const window = @import("zhu").window;
const gfx = @import("zhu").gfx;
const camera = @import("zhu").camera;

const player = @import("player.zig");

const Talk = struct {
    actor: u8 = 0,
    content: []const u8,
    format: enum { none, int } = .none,
    next: usize = 0,
};
const talks: []const Talk = @import("zon/talk.zon");
var talkTexture: gfx.Texture = undefined;

pub var talkNumber: usize = 0;
var buffer: [256]u8 = undefined;
var bufferIndex: usize = 0;

pub fn init() void {
    talkTexture = gfx.loadTexture("assets/pic/talkbar.png", .init(640, 96));
}

pub fn update(talkId: usize) usize {
    if (!window.isAnyKeyRelease(&.{ .F, .SPACE, .ENTER })) return talkId;

    bufferIndex = 0;
    return talks[talkId].next;
}

pub fn render(talkId: usize) void {
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
