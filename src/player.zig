const ecs = @import("ecs");

const zhu = @import("zhu");
const window = zhu.window;
const camera = zhu.camera;
const math = zhu.math;

const component = @import("component.zig");
const item = @import("item.zig");
const zon = @import("zon.zig");
const input = zon.input;
const map = @import("map.zig");
const worldScene = @import("world.zig");
const factory = @import("factory.zig");
const storage = @import("storage.zig");

const Collider = component.Collider;
const Player = component.actor.Player;
const Position = component.Position;

pub var itemIndex: u8 = 0;

const maxExp = 100; // 经验最大值

var bgTexture: zhu.Image = undefined;

pub fn init() void {
    bgTexture = zhu.getImage("sbar.png").?;
}

pub fn exit() void {}

pub fn openItem(data: *storage.Player) bool {
    const stats = &data.stats;
    const inventory = &data.inventory;
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
        worldScene.tip = "这东西归别人了！";
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

pub fn drawStatus(data: *const storage.Player) void {
    const pos = zhu.Vector2.xy(120, 90);
    // 背景
    zhu.batch.drawImage(bgTexture, pos.addXY(-10, -10), .{});

    // 头像
    zhu.batch.drawImage(factory.playerPhoto(), pos.addXY(10, 10), .{});
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    drawInfo(data, pos, 30);
}

fn drawInfo(
    data: *const storage.Player,
    pos: math.Vector2,
    offsetY: f32,
) void {
    const stats = data.stats;
    // 等级
    var y = 22 + offsetY;
    zhu.text.draw("等级：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("等级：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(stats.level, pos.addXY(232, y), .{
        .color = .black,
    });
    zhu.text.drawNumber(stats.level, pos.addXY(230, y - 2), .{});

    // 经验
    y += offsetY;
    zhu.text.draw("经验：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("经验：", pos.addXY(120, y - 2), .{});
    var buffer: [30]u8 = undefined;
    const expStr = zhu.format(&buffer, "{d}/{d}", .{
        stats.exp,
        maxExp,
    });
    zhu.text.draw(expStr, pos.addXY(232, y), .{ .color = .black });
    zhu.text.draw(expStr, pos.addXY(230, y - 2), .{});

    // 生命
    y += offsetY;
    zhu.text.draw("生命：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("生命：", pos.addXY(120, y - 2), .{});
    const healthStr = zhu.format(&buffer, "{d}/{d}", .{
        stats.health,
        stats.maxHealth,
    });
    zhu.text.draw(healthStr, pos.addXY(232, y), .{ .color = .black });
    zhu.text.draw(healthStr, pos.addXY(230, y - 2), .{});

    // 攻击
    y += offsetY;
    zhu.text.draw("攻击：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("攻击：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(stats.attack, pos.addXY(232, y), .{
        .color = .black,
    });
    zhu.text.drawNumber(stats.attack, pos.addXY(230, y - 2), .{});

    // 防御
    y += offsetY;
    zhu.text.draw("防御：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("防御：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(stats.defend, pos.addXY(232, y), .{
        .color = .black,
    });
    zhu.text.drawNumber(stats.defend, pos.addXY(230, y - 2), .{});

    // 速度
    y += offsetY;
    zhu.text.draw("速度：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("速度：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(stats.agility, pos.addXY(232, y), .{
        .color = .black,
    });
    zhu.text.drawNumber(stats.agility, pos.addXY(230, y - 2), .{});

    // 金币
    y += offsetY;
    zhu.text.draw("金币：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("金币：", pos.addXY(120, y - 2), .{ .color = .yellow });
    zhu.text.drawNumber(data.inventory.money, pos.addXY(232, y), .{
        .color = .black,
    });
    zhu.text.drawNumber(data.inventory.money, pos.addXY(230, y - 2), .{
        .color = .yellow,
    });
}

var needDrawInfo: bool = false;
pub fn drawOpenItem(data: *const storage.Player) void {
    item.draw(&data.inventory.items, itemIndex);
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    if (needDrawInfo) {
        zhu.text.draw("现在的状态：", .xy(272, 92), .{ .color = .black });
        zhu.text.draw("现在的状态：", .xy(270, 90), .{
            .color = .yellow,
        });
        drawInfo(data, .xy(120, 73), 20);
    }

    var buffer: [20]u8 = undefined;
    // 金币，操作说明
    zhu.text.draw("（金=", item.position.addXY(10, 270), .{});
    const moneyStr = zhu.format(
        &buffer,
        "{d}）",
        .{data.inventory.money},
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
