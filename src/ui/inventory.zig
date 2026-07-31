const zhu = @import("zhu");
const ecs = @import("ecs");

const item = @import("item.zig");
const stats = @import("stats.zig");
const storage = @import("../storage.zig");
const zon = @import("../zon.zig");

pub const Request = enum { close, used };

var index: u8 = 0; // 当前选择的背包格子。
var showStats = false; // 是否显示使用物品后的玩家属性。

// 每次打开背包时清除上一次使用物品留下的状态提示。
pub fn open() void {
    showStats = false;
}

// 处理背包中的选择、使用、丢弃和关闭操作。
pub fn update(world: *ecs.World) ?Request {
    const closeKey = zon.input.anyPressed(&.{ .menu, .cancel });
    if (closeKey or zhu.mouse.released(.RIGHT)) return .close;

    if (showStats and zhu.input.change.pressed) {
        showStats = false;
    }

    const inventory = world.getGlobal(storage.Inventory).?;
    index = item.update(inventory.items.len, index);

    const key = inventory.items[index] orelse return null;
    if (zon.input.pressed(.useItem)) {
        const playerStats = world.getGlobal(storage.Stats).?;
        const usedItem = zon.Item.get(key);

        addValue(&playerStats.exp, usedItem.exp);
        addValue(&playerStats.health, usedItem.health);
        addValue(&playerStats.attack, usedItem.attack);
        addValue(&playerStats.defend, usedItem.defend);
        if (playerStats.health > playerStats.maxHealth) {
            playerStats.health = playerStats.maxHealth;
        }

        inventory.items[index] = null;
        showStats = true;
        return .used;
    }

    if (zon.input.pressed(.dropItem)) {
        inventory.items[index] = null;
    }
    return null;
}

fn addValue(value: *u16, add: i32) void {
    const result = @as(i32, @intCast(value.*)) + add;
    value.* = if (result < 0) 0 else @intCast(result);
}

pub fn draw(world: *ecs.World) void {
    const inventory = world.getGlobal(storage.Inventory).?;
    const pos = item.position;
    item.draw(&inventory.items, index);

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    if (showStats) {
        const shadow: zhu.text.Option = .{ .color = .black };
        const gold: zhu.text.Option = .{ .color = .yellow };
        zhu.text.draw("现在的状态：", .xy(272, 92), shadow);
        zhu.text.draw("现在的状态：", .xy(270, 90), gold);
        stats.draw(world, .xy(120, 73), 20);
    }

    var buffer: [20]u8 = undefined;
    zhu.text.draw("（金=", pos.addXY(10, 270), .{});
    const money = zhu.format(&buffer, "{d}）", .{inventory.money});
    zhu.text.draw(money, pos.addXY(60, 270), .{});
    zhu.text.draw(" F=使用  G=丢弃  ESC=退出", pos.addXY(118, 270), .{});
}
