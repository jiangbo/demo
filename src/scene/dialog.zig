const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const camera = @import("../camera.zig");

const map = @import("map.zig");

const Dialog = @This();

pub var active: bool = false;

pub var background: gfx.Texture = undefined;
pub var face: gfx.Texture = undefined;
pub var left: bool = true;
pub var npc: *map.NPC = undefined;
pub var name: []const u8 = &.{};
pub var content: []const u8 = &.{};

pub fn init() void {
    background = gfx.loadTexture("assets/msg.png", .init(790, 163));
}

pub fn render() void {
    camera.draw(Dialog.background, .init(0, 415));
    if (left) {
        camera.drawTextOptions(.{
            .text = name,
            .position = .init(255, 440),
            .color = .{ .r = 0.7, .g = 0.5, .b = 0.3, .a = 1 },
        });
        camera.drawText(content, .init(305, 455));
        camera.draw(face, .init(0, 245));
    } else {
        camera.draw(npc.face.?, .init(486, 245));
    }
}
