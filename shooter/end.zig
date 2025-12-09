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

var blink: bool = true; // 输入光标闪烁
var blinkTimer: window.Timer = .init(0.7); // 输入光标闪烁
const Score = struct { name: []const u8, score: u32 };
var scoreBoard: [8]Score = undefined; // 最多显示 8 个

pub fn handleEvent(event: *const zhu.window.Event) void {
    if (!isTyping or event.type != .CHAR) return;
    if (nameIndex >= nameUnicode.len - 1) return; // 存不下了

    nameUnicode[nameIndex] = @intCast(event.char_code);
    nameIndex += 1;
    name = text.encodeUtf8(&nameBuffer, nameUnicode[0..nameIndex]);
}

pub fn update(delta: f32) void {
    if (isTyping) return updateTyping(delta);
}

fn updateTyping(delta: f32) void {
    // 输入光标闪烁计时器，应该在名称长度判断的前面，因为没有输入也闪烁。
    if (blinkTimer.isFinishedAfterUpdate(delta)) {
        blink = !blink;
        blinkTimer.reset();
    }

    if (nameIndex == 0) return; // 没有输入任何字符的时候，不处理。

    if (window.isKeyPress(.BACKSPACE)) {
        // 按退格的时候，删除一个字符，并且更新名字。
        nameIndex -= 1;
        name = text.encodeUtf8(&nameBuffer, nameUnicode[0..nameIndex]);
    }

    if (window.isKeyPress(.ENTER)) { // 确定输入
        isTyping = false;
        if (player.score > scoreBoard[scoreBoard.len - 1].score) {
            // 只有大于最小的得分，才进行保存。
            saveScore();
        }
    }
}

fn saveScore() void {}

pub fn draw() void {
    if (isTyping) return drawTyping();
}

fn drawTyping() void {
    var buffer: [255]u8 = undefined;
    const score = zhu.format(&buffer, "你的得分是：{}", .{player.score});
    text.drawCenter(score, 0.1, .{ .spacing = 2 });

    text.drawCenter("GAME OVER", 0.35, .{ .size = 72, .spacing = 5 });

    const typing = "请输入你的名字，按回车键确认：";
    text.drawCenter(typing, 0.6, .{ .spacing = 2 });

    if (nameIndex == 0) {
        if (blink) text.drawCenter("_", 0.8, .{ .spacing = 2 });
    } else {
        const width = text.computeTextWidthOption(name, .{ .spacing = 2 });
        const x = (window.logicSize.x - width) / 2;
        const pos: zhu.math.Vector = .init(x, window.logicSize.y * 0.8);
        text.drawOption(name, pos, .{ .spacing = 2 });
        if (blink) text.draw("_", pos.addX(width + 4));
    }
}
