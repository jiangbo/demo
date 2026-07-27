const ecs = @import("ecs");

const zhu = @import("zhu");
const window = zhu.window;
const camera = zhu.camera;
const math = zhu.math;

const component = @import("component.zig");
const item = @import("item.zig");
const statsUi = @import("ui/stats.zig");
const zon = @import("zon.zig");
const input = zon.input;
const map = @import("map.zig");
const storage = @import("storage.zig");

const Collider = component.Collider;
const Player = component.actor.Player;
const Position = component.Position;

pub var itemIndex: u8 = 0;

const maxExp = 100; // 经验最大值

pub fn openItem(
    stats: *storage.Stats,
    inventory: *storage.Inventory,
) bool {
    if (needDrawInfo and
        (input.released(.confirm) or input.released(.cancel)))
    {
        needDrawInfo = false;
    }
    itemIndex = item.update(inventory.items.len, itemIndex);

    const key = inventory.items[itemIndex] orelse return false;

    if (input.released(.useItem)) {
        //  使用物品
        // TODO 绘制状态
        const usedItem = zon.Item.get(key);

        addStatusValue(&stats.exp, usedItem.exp);
        addStatusValue(&stats.health, usedItem.health);
        addStatusValue(&stats.attack, usedItem.attack);
        addStatusValue(&stats.defend, usedItem.defend);
        if (stats.health > stats.maxHealth) {
            stats.health = stats.maxHealth;
        }
        inventory.items[itemIndex] = null;
        needDrawInfo = true;

        return true;
    } else if (input.released(.dropItem)) {
        // 丢弃物品
        inventory.items[itemIndex] = null;
    }

    return false;
}

fn addStatusValue(value: *u16, add: i32) void {
    const tmp = @as(i32, @intCast(value.*)) + add;
    value.* = if (tmp < 0) 0 else @intCast(tmp);
}

var sellItemKey: ?zon.Item.Key = null;
pub fn sellItem(inventory: *storage.Inventory) bool {
    if (sellItemKey != null) {
        if (input.released(.confirm) or input.released(.cancel)) {
            sellItemKey = null;
        }
        return false;
    }

    itemIndex = item.update(inventory.items.len, itemIndex);

    const key = inventory.items[itemIndex] orelse return false;

    if (input.released(.useItem)) {
        // 卖出物品
        sellItemKey = key;
        const usedItem = zon.Item.get(key);
        inventory.money += usedItem.money / 2;
        inventory.items[itemIndex] = null;
        return true;
    }
    return false;
}

pub fn cameraLookAt(world: *ecs.World) void {
    const area = collider(world);
    const half = window.size.scale(0.5);
    const max = map.current.grid.size().sub(window.size);
    camera.main.position = area.min.sub(half).clamp(.zero, max);
}

pub fn collider(world: *ecs.World) math.Rect {
    const entity = world.getIdentity(Player).?;
    const position = world.get(entity, Position).?;
    const value = world.get(entity, Collider).?;
    return value.move(position);
}

pub fn isLevelUp(stats: storage.Stats) bool {
    return stats.exp >= maxExp;
}

pub fn levelUp(stats: *storage.Stats) void {
    stats.level += stats.exp / maxExp;
    stats.maxHealth += stats.exp / maxExp * 30;
    stats.attack += stats.exp / maxExp * 1;
    stats.defend += stats.exp / maxExp * 1;
    stats.health += (stats.maxHealth - stats.health) / 2;
    stats.exp %= maxExp;
    stats.health = stats.maxHealth;
}

var needDrawInfo: bool = false;
pub fn drawOpenItem(world: *ecs.World) void {
    const inventory = world.getGlobal(storage.Inventory).?;
    item.draw(&inventory.items, itemIndex);
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    if (needDrawInfo) {
        const shadow: zhu.text.Option = .{ .color = .black };
        const gold: zhu.text.Option = .{ .color = .yellow };
        zhu.text.draw("现在的状态：", .xy(272, 92), shadow);
        zhu.text.draw("现在的状态：", .xy(270, 90), gold);
        statsUi.draw(world, .xy(120, 73), 20);
    }

    var buffer: [20]u8 = undefined;
    // 金币，操作说明
    zhu.text.draw("（金=", item.position.addXY(10, 270), .{});
    const moneyStr = zhu.format(
        &buffer,
        "{d}）",
        .{inventory.money},
    );
    zhu.text.draw(moneyStr, item.position.addXY(60, 270), .{});
    const text = " F=使用  G=丢弃  ESC=退出";
    zhu.text.draw(text, item.position.addXY(118, 270), .{});
}

pub fn drawSellItem(inventory: *const storage.Inventory) void {
    item.draw(&inventory.items, itemIndex);
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    var buffer: [50]u8 = undefined;
    if (sellItemKey) |key| {
        const itemInfo = zon.Item.get(key);
        const sellTip = zhu.format(&buffer, "卖掉[{s}]得到：{d}", .{
            itemInfo.name,
            itemInfo.money / 2,
        });
        zhu.text.draw(sellTip, item.position.addXY(102, 110), .{
            .color = .black,
        });
        zhu.text.draw(sellTip, item.position.addXY(100, 108), .{});
    }

    zhu.text.draw("（金=", item.position.addXY(10, 270), .{});
    const moneyStr = zhu.format(&buffer, "{d}）", .{
        inventory.money,
    });
    zhu.text.draw(moneyStr, item.position.addXY(60, 270), .{});
    const text = "CTRL=卖出  ESC=退出";
    zhu.text.draw(text, item.position.addXY(118, 270), .{});
}
