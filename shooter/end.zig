const std = @import("std");
const zhu = @import("zhu");

const camera = zhu.camera;
const text = zhu.text;
const window = zhu.window;

const player = @import("player.zig");

var isTyping: bool = true;
var nameUnicode: [20]u21 = undefined;
var nameIndex: u8 = 0;
var nameBuffer: [nameUnicode.len * 3]u8 = undefined;
var name: []u8 = &.{};

pub fn handleEvent(event: *const zhu.window.Event) void {
    if (!isTyping or event.type != .CHAR) return;

    nameUnicode[nameIndex] = @intCast(event.char_code);
    nameIndex += 1;
    name = text.encodeUtf8(&nameBuffer, nameUnicode[0..nameIndex]);
    std.log.info("handle event", .{});
}

pub fn update(delta: f32) void {
    _ = delta;
    updateTyping();
}

fn updateTyping() void {
    if (nameIndex == 0) return; // 没有输入任何字符的时候，不处理。

    if (window.isKeyPress(.BACKSPACE)) {
        // 按退格的时候，删除一个字符，并且更新名字。
        nameIndex -= 1;
        name = text.encodeUtf8(&nameBuffer, nameUnicode[0..nameIndex]);
    }
}

pub fn draw() void {
    var buffer: [255]u8 = undefined;
    const score = zhu.format(&buffer, "你的得分是：{}", .{player.score});
    text.drawCenter(score, 0.1, .{ .spacing = 2 });

    text.drawCenter("GAME OVER", 0.35, .{ .size = 72, .spacing = 5 });

    const typing = "请输入你的名字，按回车键确认：";
    text.drawCenter(typing, 0.6, .{ .spacing = 2 });

    if (nameIndex > 0) {
        text.drawCenter(name, 0.8, .{ .spacing = 2 });
    }
}
