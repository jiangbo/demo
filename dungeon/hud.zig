const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;
const math = zhu.math;
const ecs = zhu.ecs;

const player = @import("player.zig");
const battle = @import("battle.zig");

var texture: gfx.Texture = undefined;
const healthForeground: math.Vector4 = .init(0.298, 0.735, 0.314, 1);
const healthBackground: math.Vector4 = .init(0.2, 0.2, 0.2, 1);

pub fn init() void {
    texture = gfx.loadTexture("assets/terminal8x8.png", .init(128, 128));
    camera.whiteTexture = texture.subTexture(.init(.init(88, 104), size));
}

pub fn draw() void {
    camera.mode = .local;
    defer camera.mode = .world;

    var pos: gfx.Vector = .init(window.logicSize.x / 2, 10);
    var healthSize: gfx.Vector = .init(200, 12);
    const healthPos = pos.sub(healthSize.scale(0.5));

    const health = ecs.w.get(player.entity, battle.Health).?;
    var buffer: [50]u8 = undefined;
    const text = zhu.format(&buffer, "Health: {} / {}", //
        .{ health.current, health.max });

    camera.drawRect(.init(healthPos, healthSize), healthBackground);
    healthSize.x *= math.percentInt(health.current, health.max);
    camera.drawRect(.init(healthPos, healthSize), healthForeground);

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
