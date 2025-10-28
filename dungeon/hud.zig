const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
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
    drawText(text, .init(250, 5));
    drawText("Explore the Dungeon. A/S/D/W to move.", .init(170, 20));
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

fn computeTextSize(text: []const u8) gfx.Vector {
    var rows: f32 = 0;
    var columns: f32 = 0;
    var maxColumns: f32 = 0;
    for (text) |byte| {
        if (byte == '\n') {
            rows += 1;
            columns = 0;
        }
        columns += 1;
        if (columns > maxColumns) maxColumns = columns;
    }
    return size.mul(.init(maxColumns + 1, rows + 1));
}
