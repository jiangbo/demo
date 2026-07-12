const std = @import("std");
const zhu = @import("zhu");

const input = @import("input.zig");

pub const Item = struct {
    id: u16,
    name: []const u8 = &.{},
    about: []const u8 = &.{},
    money: u32 = 0,
    exp: i32 = 0,
    health: i32 = 0,
    attack: i32 = 0,
    defend: i32 = 0,
};

pub const Pickup = struct { itemIndex: u8, count: u8 };

pub const zon: []const Item = @import("zon/item.zon");
pub const pickupZon: []const Pickup = @import("zon/pickup.zon");
pub const position: zhu.Vector2 = .xy(120, 90);

pub var picked: std.StaticBitSet(32) = .initEmpty();

var texture: zhu.Image = undefined;
var bgTexture: zhu.Image = undefined;

pub fn init() void {
    texture = zhu.getImage("goods.png").?;
    bgTexture = zhu.getImage("sbar.png").?;
}

pub fn update(len: u8, index: u8) u8 {
    var itemIndex = index;

    if (input.released(.left)) {
        itemIndex = (itemIndex + len - 1) % len;
    }

    if (input.released(.right)) {
        itemIndex = (itemIndex + 1) % len;
    }

    if (input.released(.down)) {
        itemIndex = (itemIndex + len / 2) % len;
    }

    if (input.released(.up)) {
        itemIndex = (itemIndex + len / 2 * 3) % len;
    }
    return itemIndex;
}

pub fn draw(items: []const u8, itemIndex: usize) void {
    zhu.batch.drawImage(bgTexture, position.addXY(-10, -10), .{});

    // 当前选中物品
    var buffer: [32]u8 = undefined;
    if (items[itemIndex] != 0) {
        const current = zon[items[itemIndex]];
        zhu.text.msdf.begin();

        zhu.text.draw(current.name, position.addXY(70, 20), .{});
        zhu.text.draw(" (价值：", position.addXY(180, 20), .{});
        const text = zhu.format(&buffer, "{d}）", .{current.money});
        zhu.text.draw(text, position.addXY(260, 20), .{});

        zhu.text.draw("经验：", position.addXY(20, 60), .{});
        zhu.text.drawNumber(current.exp, position.addXY(100, 60), .{});

        zhu.text.draw("生命：", position.addXY(20, 86), .{});
        zhu.text.drawNumber(current.health, position.addXY(100, 86), .{});

        zhu.text.draw("攻击：", position.addXY(20, 112), .{});
        zhu.text.drawNumber(current.attack, position.addXY(100, 112), .{});

        zhu.text.draw("防御：", position.addXY(20, 134), .{});
        zhu.text.drawNumber(current.defend, position.addXY(100, 134), .{});

        // 描述
        zhu.text.draw(current.about, position.addXY(170, 60), .{
            .color = .yellow,
        });
        zhu.text.msdf.end();
    }

    const itemBg = getIconFromIndex(0);
    const itemSelected = getIconFromIndex(1);

    const offset = position.addXY(5, 170);

    for (0..2) |i| {
        const row: f32 = @floatFromInt(i);
        for (0..8) |j| {
            const col: f32 = @floatFromInt(j);
            const itemPos = offset.addXY(col * 49, row * 49);
            zhu.batch.drawImage(itemBg, itemPos, .{});

            const index = j + 8 * i;
            defer if (itemIndex == index) {
                zhu.batch.drawImage(itemSelected, itemPos, .{});
            };
            if (items[index] == 0) continue;

            zhu.batch.drawImage(
                getIconFromIndex(items[index] - 2),
                itemPos,
                .{},
            );
        }
    }
}

fn getIconFromIndex(index: usize) zhu.Image {
    const row: f32 = @floatFromInt(index / 8);
    const col: f32 = @floatFromInt(index % 8);
    const pos = zhu.Vector2.xy(col * 48, row * 48);
    return texture.sub(.init(pos, .xy(48, 48)));
}
