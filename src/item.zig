const zhu = @import("zhu");

const zon = @import("zon.zig");
const input = zon.input;
pub const position: zhu.Vector2 = .xy(120, 90);

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

pub fn draw(items: []const ?zon.Item.Key, itemIndex: usize) void {
    zhu.batch.drawImage(bgTexture, position.addXY(-10, -10), .{});

    // 当前选中物品
    var buffer: [32]u8 = undefined;
    if (items[itemIndex]) |key| {
        const current = zon.Item.get(key);
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

    const itemBg = getIcon(0);
    const itemSelected = getIcon(1);

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
            const key = items[index] orelse continue;

            zhu.batch.drawImage(
                getIcon(zon.Item.get(key).icon),
                itemPos,
                .{},
            );
        }
    }
}

fn getIcon(icon: usize) zhu.Image {
    const row: f32 = @floatFromInt(icon / 8);
    const col: f32 = @floatFromInt(icon % 8);
    const pos = zhu.Vector2.xy(col * 48, row * 48);
    return texture.sub(.init(pos, .xy(48, 48)));
}
