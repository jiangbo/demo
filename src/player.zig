const ecs = @import("ecs");

const zhu = @import("zhu");
const window = zhu.window;
const camera = zhu.camera;
const math = zhu.math;

const component = @import("component.zig");
const item = @import("item.zig");
const input = @import("input.zig");
const map = @import("map.zig");
const worldScene = @import("world.zig");
const factory = @import("factory.zig");

const Collider = component.Collider;
const Player = component.Player;
const Position = component.Position;

pub var money: u32 = 50; // 金钱
pub var items: [16]u8 = undefined;
pub var itemIndex: u8 = 0;

pub var level: u16 = 1; //等级
pub var exp: u16 = 0; //经验
const maxExp = 100; //经验最大值
pub var health: u16 = 50; //生命
pub var maxHealth: u16 = 50; //生命最大值
pub var attack: u16 = 10; //攻击
pub var defend: u16 = 10; //防御
pub var speed: u16 = 8; //速度
pub var progress: u8 = 1; //进度

var bgTexture: zhu.Image = undefined;

pub fn init() void {
    bgTexture = zhu.getImage("sbar.png").?;

    @memset(&items, 0);
}

pub fn exit() void {}

pub fn openItem() bool {
    if (needDrawInfo and
        (input.released(.confirm) or input.released(.cancel)))
    {
        needDrawInfo = false;
    }
    itemIndex = item.update(items.len, itemIndex);

    if (items[itemIndex] == 0) return false;

    if (input.released(.useItem)) {
        //  使用物品
        // TODO 绘制状态
        const usedItem = item.zon[items[itemIndex]];

        addStatusValue(&exp, usedItem.exp);
        addStatusValue(&health, usedItem.health);
        addStatusValue(&attack, usedItem.attack);
        addStatusValue(&defend, usedItem.defend);
        if (health > maxHealth) health = maxHealth;
        items[itemIndex] = 0;
        needDrawInfo = true;

        return true;
    } else if (input.released(.dropItem)) {
        // 丢弃物品
        items[itemIndex] = 0;
    }

    return false;
}

fn addStatusValue(value: *u16, add: i32) void {
    const tmp = @as(i32, @intCast(value.*)) + add;
    value.* = if (tmp < 0) 0 else @intCast(tmp);
}

var sellItemIndex: u16 = 0;
pub fn sellItem() bool {
    if (sellItemIndex != 0) {
        if (input.released(.confirm) or input.released(.cancel)) {
            sellItemIndex = 0;
        }
        return false;
    }

    itemIndex = item.update(items.len, itemIndex);

    if (items[itemIndex] == 0) return false;

    if (input.released(.useItem)) {
        // 卖出物品
        sellItemIndex = items[itemIndex];
        const usedItem = item.zon[sellItemIndex];
        money += usedItem.money / 2;
        items[itemIndex] = 0;
        worldScene.tip = "这东西归别人了！";
        return true;
    }
    return false;
}

pub fn cameraLookAt(world: *ecs.World) void {
    const area = collider(world);
    const half = window.size.scale(0.5);
    const max = map.size.sub(window.size);
    camera.main.position = area.min.sub(half).clamp(.zero, max);
}

pub fn collider(world: *ecs.World) math.Rect {
    const entity = world.getIdentity(Player).?;
    const position = world.get(entity, Position).?;
    const value = world.get(entity, Collider).?;
    return value.move(position);
}

pub fn addItem(itemId: u8) bool {
    for (&items) |*value| {
        if (value.* == 0) {
            value.* = itemId;
            return true;
        }
    }
    return false;
}

pub fn isLevelUp() bool {
    return exp >= maxExp;
}

pub fn levelUp() void {
    level += exp / maxExp;
    maxHealth += exp / maxExp * 30;
    attack += exp / maxExp * 1;
    defend += exp / maxExp * 1;
    health += (maxHealth - health) / 2;
    exp %= maxExp;
    health = maxHealth;
}

pub fn drawStatus() void {
    const pos = zhu.Vector2.xy(120, 90);
    // 背景
    zhu.batch.drawImage(bgTexture, pos.addXY(-10, -10), .{});

    // 头像
    zhu.batch.drawImage(factory.playerPhoto(), pos.addXY(10, 10), .{});
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    drawInfo(pos, 30);
}

fn drawInfo(pos: math.Vector2, offsetY: f32) void {
    // 等级
    var y = 22 + offsetY;
    zhu.text.draw("等级：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("等级：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(level, pos.addXY(232, y), .{ .color = .black });
    zhu.text.drawNumber(level, pos.addXY(230, y - 2), .{});

    // 经验
    y += offsetY;
    zhu.text.draw("经验：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("经验：", pos.addXY(120, y - 2), .{});
    var buffer: [30]u8 = undefined;
    const expStr = zhu.format(&buffer, "{d}/{d}", .{ exp, maxExp });
    zhu.text.draw(expStr, pos.addXY(232, y), .{ .color = .black });
    zhu.text.draw(expStr, pos.addXY(230, y - 2), .{});

    // 生命
    y += offsetY;
    zhu.text.draw("生命：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("生命：", pos.addXY(120, y - 2), .{});
    const healthStr = zhu.format(&buffer, "{d}/{d}", .{ health, maxHealth });
    zhu.text.draw(healthStr, pos.addXY(232, y), .{ .color = .black });
    zhu.text.draw(healthStr, pos.addXY(230, y - 2), .{});

    // 攻击
    y += offsetY;
    zhu.text.draw("攻击：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("攻击：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(attack, pos.addXY(232, y), .{ .color = .black });
    zhu.text.drawNumber(attack, pos.addXY(230, y - 2), .{});

    // 防御
    y += offsetY;
    zhu.text.draw("防御：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("防御：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(defend, pos.addXY(232, y), .{ .color = .black });
    zhu.text.drawNumber(defend, pos.addXY(230, y - 2), .{});

    // 速度
    y += offsetY;
    zhu.text.draw("速度：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("速度：", pos.addXY(120, y - 2), .{});
    zhu.text.drawNumber(speed, pos.addXY(232, y), .{ .color = .black });
    zhu.text.drawNumber(speed, pos.addXY(230, y - 2), .{});

    // 金币
    y += offsetY;
    zhu.text.draw("金币：", pos.addXY(122, y), .{ .color = .black });
    zhu.text.draw("金币：", pos.addXY(120, y - 2), .{ .color = .yellow });
    zhu.text.drawNumber(money, pos.addXY(232, y), .{ .color = .black });
    zhu.text.drawNumber(money, pos.addXY(230, y - 2), .{
        .color = .yellow,
    });
}

var needDrawInfo: bool = false;
pub fn drawOpenItem() void {
    item.draw(&items, itemIndex);
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    if (needDrawInfo) {
        zhu.text.draw("现在的状态：", .xy(272, 92), .{ .color = .black });
        zhu.text.draw("现在的状态：", .xy(270, 90), .{
            .color = .yellow,
        });
        drawInfo(.xy(120, 73), 20);
    }

    var buffer: [20]u8 = undefined;
    // 金币，操作说明
    zhu.text.draw("（金=", item.position.addXY(10, 270), .{});
    const moneyStr = zhu.format(&buffer, "{d}）", .{money});
    zhu.text.draw(moneyStr, item.position.addXY(60, 270), .{});
    const text = " F=使用  G=丢弃  ESC=退出";
    zhu.text.draw(text, item.position.addXY(118, 270), .{});
}

pub fn drawSellItem() void {
    item.draw(&items, itemIndex);
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();

    var buffer: [50]u8 = undefined;
    if (sellItemIndex != 0) {
        const itemInfo = item.zon[sellItemIndex];
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
    const moneyStr = zhu.format(&buffer, "{d}）", .{money});
    zhu.text.draw(moneyStr, item.position.addXY(60, 270), .{});
    const text = "CTRL=卖出  ESC=退出";
    zhu.text.draw(text, item.position.addXY(118, 270), .{});
}
