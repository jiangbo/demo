const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;
const ecs = zhu.ecs;

const player = @import("player.zig");
const battle = @import("battle.zig");

var texture: gfx.Texture = undefined;

pub fn init() void {
    texture = gfx.loadTexture("assets/terminal8x8.png", .init(128, 128));
}

pub fn draw() void {
    const health = ecs.w.get(player.entity, battle.Health).?;

    var buffer: [50]u8 = undefined;
    const text = zhu.format(&buffer, "Health: {} / {}", //
        .{ health.current, health.max });
    var pos: gfx.Vector = .init(window.logicSize.x / 2, 10);
    drawTextCenter(text, pos);
    pos.y += size.x * 2;
    drawTextCenter("Explore the Dungeon. A/S/D/W to move.", pos);
}

fn drawTextCenter(text: []const u8, position: gfx.Vector) void {
    const textSize = size.mul(.init(@floatFromInt(text.len), 1));
    drawText(text, position.sub(textSize.scale(0.5)));
}
const size: gfx.Vector = .init(8, 8);
fn drawText(text: []const u8, position: gfx.Vector) void {
    camera.mode = .local;
    defer camera.mode = .world;

    var pos = position;

    for (text) |byte| {
        const x: f32 = @floatFromInt(byte % 16);
        const y: f32 = @floatFromInt(byte / 16);
        const charTexture = texture.subTexture(.{
            .min = size.mul(.init(x, y)),
            .size = size,
        });

        camera.draw(charTexture, pos);
        pos.x += size.x;
    }
}
