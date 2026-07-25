const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const factory = @import("../factory.zig");
const zon = @import("../zon.zig");

const Dialog = component.dialog.Dialog;
const Interact = component.Interact;
const Player = component.Player;

var texture: zhu.Image = undefined;
// 动态文本格式化后存放在此缓冲区。
var buffer: [256]u8 = undefined;

pub fn init() void {
    texture = zhu.getImage("talkbar.png").?;
}

pub fn update(world: *ecs.World) ?zon.dialog.Event {
    const dialog = world.getPtr(world.entity, Dialog) orelse return null;
    if (dialog.text == null) {
        prepareText(dialog);
        return null;
    }
    if (!zon.input.released(.confirm)) return null;

    const line = dialog.lines[dialog.line];
    if (line.event) |event| {
        switch (event) {
            .battle => {
                if (dialog.line + 1 == dialog.lines.len) close(world) else {
                    dialog.line += 1;
                    prepareText(dialog);
                }
            },
            else => close(world),
        }
        return event;
    }

    if (dialog.line + 1 == dialog.lines.len) {
        close(world);
        return .finish;
    }

    dialog.line += 1;
    prepareText(dialog);
    return null;
}

pub fn draw(world: *ecs.World) void {
    const dialog = world.get(world.entity, Dialog) orelse return;
    const text = dialog.text orelse return;
    const line = dialog.lines[dialog.line];

    zhu.batch.drawImage(texture, .xy(0, 384), .{});
    if (line.actor) |key| {
        const actor = zon.getActor(key);
        if (key == .player) {
            drawActor(factory.playerPhoto(), .xy(35, 396), actor.name);
        } else {
            drawActor(factory.npcPhoto(key), .xy(40, 400), actor.name);
        }
    }

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    drawText(text);
}

fn prepareText(dialog: *Dialog) void {
    const line = dialog.lines[dialog.line];
    const value = dialog.value orelse {
        dialog.text = line.content;
        return;
    };

    var buf: [20]u8 = undefined;
    const text = switch (value) {
        .number => |number| zhu.format(&buf, "{d}", .{number}),
        .text => |v| v,
    };
    const times = std.mem.replace(u8, line.content, "{}", text, &buffer);
    std.debug.assert(times == 1);
    const length = line.content.len - 2 + text.len;
    dialog.text = buffer[0..length];
}

fn close(world: *ecs.World) void {
    world.remove(world.entity, Dialog);
    world.remove(world.getIdentity(Player).?, Interact.Disabled);
    world.removeIdentity(Interact);
}

fn drawActor(image: zhu.Image, position: zhu.Vector2, name: []const u8) void {
    zhu.batch.drawImage(image, position, .{});

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(name, .xy(25, 445), .{ .color = .yellow });
}

fn drawText(content: []const u8) void {
    zhu.text.draw(content, .xy(123, 400), .{ .color = .black, .max = 593 });
    zhu.text.draw(content, .xy(120, 397), .{ .color = .white, .max = 590 });
}
