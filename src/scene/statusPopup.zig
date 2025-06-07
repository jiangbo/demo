const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const world = @import("world.zig");
const camera = @import("../camera.zig");

pub const MenuType = enum { item, skill };

pub var display: bool = false;
var position: gfx.Vector = undefined;
var background: gfx.Texture = undefined;
var selected: gfx.Texture = undefined;
var itemTexture: gfx.Texture = undefined;
var skillTexture: gfx.Texture = undefined;

var selectedPlayer: usize = 0;
var selectedItem: usize = 0;
var menuType: MenuType = .item;

pub fn init() void {
    position = .init(58, 71);
    background = gfx.loadTexture("assets/item/status_bg.png", .init(677, 428));
    selected = gfx.loadTexture("assets/item/sbt7_2.png", .init(273, 90));
    itemTexture = gfx.loadTexture("assets/item/sbt2_1.png", .init(62, 255));
    skillTexture = gfx.loadTexture("assets/item/sbt2_2.png", .init(62, 255));
}

pub fn update(delta: f32) void {
    if (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E })) display = false;

    if (window.isAnyKeyRelease(&.{ .LEFT, .A })) {
        selectedPlayer += world.players.len;
        selectedPlayer = (selectedPlayer - 1) % world.players.len;
    } else if (window.isAnyKeyRelease(&.{ .RIGHT, .D })) {
        selectedPlayer = (selectedPlayer + 1) % world.players.len;
    }

    if (window.isKeyRelease(.TAB)) {
        menuType = if (menuType == .item) .skill else .item;
    }

    _ = delta;
}

pub fn render() void {
    if (!display) return;

    camera.draw(background, position);

    renderStatus();

    var items: []world.Item = undefined;

    if (menuType == .item) {
        items = &world.items;
        camera.draw(itemTexture, position.add(.init(629, 51)));
    } else {
        items = &world.skills;
        camera.draw(skillTexture, position.add(.init(629, 51)));
    }

    var showItemCount: usize = 0;
    for (items) |item| {
        if (item.count == 0) continue;

        const offset = position.add(.init(360, 48));
        const pos = offset.addY(@floatFromInt(96 * showItemCount));
        camera.draw(item.texture, pos);

        if (selectedItem == showItemCount) {
            camera.draw(selected, pos.sub(.init(10, 10)));
        }

        showItemCount += 1;
        if (showItemCount >= 3) break;
    }
}

fn renderStatus() void {
    const player = &world.players[selectedPlayer];
    camera.draw(player.statusTexture, position);

    var buffer: [32]u8 = undefined;
    if (player.attackItem) |item| {
        camera.draw(item.texture, position.add(.init(41, 55)));
    }

    if (player.defendItem) |item| {
        camera.draw(item.texture, position.add(.init(41, 136)));
    }

    drawText(&buffer, .{player.health}, .init(155, 411));
    drawText(&buffer, .{player.mana}, .init(290, 411));

    const item = &player.totalItem;
    drawText(&buffer, .{player.attack}, .init(155, 431));
    drawEffect(&buffer, .{item.value2}, .init(185, 431));
    drawText(&buffer, .{player.defend}, .init(290, 431));
    drawEffect(&buffer, .{item.value3}, .init(320, 431));

    drawText(&buffer, .{player.speed}, .init(155, 451));
    drawEffect(&buffer, .{item.value4}, .init(185, 451));
    drawText(&buffer, .{player.luck}, .init(290, 451));
    drawEffect(&buffer, .{item.value5}, .init(320, 451));
}

fn drawText(buffer: []u8, args: anytype, pos: gfx.Vector) void {
    const text = std.fmt.bufPrint(buffer, "{}", args);
    camera.drawTextOptions(.{
        .text = text catch unreachable,
        .position = pos,
        .color = .{ .r = 0.21, .g = 0.09, .b = 0.01, .a = 1 },
    });
}

fn drawEffect(buffer: []u8, args: anytype, pos: gfx.Vector) void {
    const text = std.fmt.bufPrint(buffer, "+{}", args);
    camera.drawTextOptions(.{
        .text = text catch unreachable,
        .position = pos,
        .color = .{ .r = 1, .a = 1 },
    });
}
