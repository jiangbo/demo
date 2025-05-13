const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");

pub const MenuType = enum { item, skill };

pub var display: bool = false;
var position: gfx.Vector = undefined;
var background: gfx.Texture = undefined;
var selectedPlayer: usize = 0;
var menuType: MenuType = .item;

pub fn init() void {
    position = .init(58, 71);
    background = gfx.loadTexture("assets/item/status_bg.png", .init(677, 428));
}

pub fn update(delta: f32) void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E })) display = false;

    if (window.isAnyKeyRelease(&.{ .LEFT, .A })) {
        selectedPlayer += world.players.len;
        selectedPlayer = (selectedPlayer - 1) % world.players.len;
    } else if (window.isAnyKeyRelease(&.{ .RIGHT, .D })) {
        selectedPlayer = (selectedPlayer + 1) % world.players.len;
    }

    _ = delta;
}

pub fn render(camera: *gfx.Camera) void {
    if (!display) return;

    camera.draw(background, position);

    const player = &world.players[selectedPlayer];
    camera.draw(player.statusTexture, position);

    if (player.attack) |attack| {
        camera.draw(attack, position.add(.init(41, 55)));
    }

    if (player.defend) |defend| {
        camera.draw(defend, position.add(.init(41, 136)));
    }

    var showItemCount: f32 = 0;
    for (&world.items) |item| {
        if (item.count == 0) continue;

        const offset = position.add(.init(360, 48));
        camera.draw(item.texture, offset.addY(96 * showItemCount));
        showItemCount += 1;
        if (showItemCount >= 3) break;
    }
}
