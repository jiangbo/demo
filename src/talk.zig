const std = @import("std");
const zhu = @import("zhu");

const factory = @import("factory.zig");
const input = @import("input.zig");

pub const Event = enum {
    finish,
    openWeaponShop,
    openPotionShop,
    openSale,
    startBattleThenTalk,
    startBattleThenMap,
    showSwordTip,
    showEnding,
};

const Line = struct {
    actor: ?factory.Key,
    content: []const u8 = &.{},
    event: ?Event = null,
};

const Dialogue = struct {
    id: u16,
    lines: []const Line,
};

const dialogues: []const Dialogue = @import("zon/talk.zon");

comptime {
    for (dialogues, 0..) |dialogue, id| {
        if (dialogue.id != id) {
            @compileError("对话 ID 必须连续并按顺序排列");
        }
    }
}

var texture: zhu.Image = undefined;

var activeDialogue: u16 = undefined;
var activeLine: usize = 0;
var textIndex: usize = 0;
var text: [50]u8 = undefined;
var plainText: bool = true;

var buffer: [256]u8 = undefined;
var bufferIndex: usize = 0;

pub fn init() void {
    texture = zhu.getImage("talkbar.png").?;
}

pub fn startNumber(dialogueId: u16, number: anytype) void {
    const content = zhu.format(text[20..], "{d}", .{number});
    startText(dialogueId, content);
}

pub fn startText(dialogueId: u16, content: []const u8) void {
    start(dialogueId);
    @memcpy(text[0..content.len], content);
    textIndex = content.len;
    bufferIndex = 0;
    plainText = false;
}

pub fn start(dialogueId: u16) void {
    activeDialogue = dialogueId;
    activeLine = 0;
    plainText = true;
}

pub fn next() void {
    activeLine += 1;
}

pub fn recentActor() factory.Key {
    const dialogue = dialogues[activeDialogue];
    var lineIndex = activeLine;
    while (dialogue.lines[lineIndex].actor == .player) {
        lineIndex -= 1;
    }
    return dialogue.lines[lineIndex].actor.?;
}

pub fn update() ?Event {
    if (!input.released(.confirm)) return null;

    const dialogue = dialogues[activeDialogue];
    const line = dialogue.lines[activeLine];
    if (line.event) |event| {
        plainText = true;
        return event;
    }
    if (activeLine + 1 == dialogue.lines.len) {
        plainText = true;
        return .finish;
    }
    activeLine += 1;
    return null;
}

pub fn draw() void {
    zhu.batch.drawImage(texture, .xy(0, 384), .{});

    const dialogue = dialogues[activeDialogue];
    const line = dialogue.lines[activeLine];
    if (line.actor) |key| {
        const data = factory.get(key);
        if (key == .player) {
            drawActor(factory.playerPhoto(), .xy(35, 396), data.name);
        } else {
            drawActor(
                factory.npcPhoto(key),
                .xy(40, 400),
                data.name,
            );
        }
    }

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    if (plainText) return drawText(line.content);

    if (bufferIndex != 0) {
        drawText(buffer[0..bufferIndex]);
    } else {
        drawText(formatStr(line.content));
    }
}

fn drawActor(image: zhu.Image, position: zhu.Vector2, name: []const u8) void {
    zhu.batch.drawImage(image, position, .{});

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(name, .xy(25, 445), .{ .color = .yellow });
}

pub fn drawText(content: []const u8) void {
    zhu.text.draw(content, .xy(123, 400), .{
        .color = .black,
        .max = 593,
    });
    zhu.text.draw(content, .xy(120, 397), .{
        .color = .white,
        .max = 590,
    });
}

fn formatStr(content: []const u8) []const u8 {
    const str = text[0..textIndex];
    const times = std.mem.replace(u8, content, "{}", str, &buffer);
    std.debug.assert(times == 1);

    bufferIndex = content.len - 2 + str.len;
    return buffer[0..bufferIndex];
}
