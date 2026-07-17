const std = @import("std");
const ecs = @import("ecs");

const zhu = @import("zhu");
const window = zhu.window;
const camera = zhu.camera;
const math = zhu.math;

const item = @import("item.zig");
const input = @import("input.zig");
const map = @import("map.zig");
const npc = @import("npc.zig");
const worldScene = @import("world.zig");
const factory = @import("factory.zig");
const Direction = @import("context.zig").Direction;

const Animation = zhu.Animation;

const name = "小飞刀";
const MOVE_SPEED = 100;
pub const SIZE: zhu.Vector2 = .xy(16, 16);
var animation: Animation = undefined;

var facings: std.EnumArray(Direction, u64) = undefined;
pub var facing: Direction = .down;
pub var position: zhu.Vector2 = undefined;

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
    animation = factory.playerAnimation();

    facings = .initFill(0);
    @memset(&items, 0);
}

pub fn enter(playerPosition: math.Vector2) void {
    position = playerPosition;
    cameraLookAt();
}

pub fn exit() void {}

pub fn update(world: *ecs.World, delta: f32) void {

    // 角色移动和碰撞检测
    const dir = updateFacing();
    if (dir.x == 0 and dir.y == 0) return; // 没有移动
    const sourceIndex: u8 = switch (facing) {
        .down => 0,
        .left => 1,
        .right => 2,
        .up => 3,
    };
    if (animation.sourceIndex != sourceIndex) animation.play(sourceIndex);
    _ = animation.update(delta);

    const velocity = dir.normalize().scale(MOVE_SPEED).scale(delta);

    const area = math.Rect.init(position, SIZE);
    if (npc.isCollision(world, area.move(velocity))) return;

    position = map.walkTo(area, velocity);
    // 相机跟踪
    cameraLookAt();
}

fn updateFacing() math.Vector2 {
    const count = window.frameCount();
    var dir = zhu.Vector2.zero;

    if (input.held(.up)) {
        dir.y -= 1;
        if (facings.get(.up) == 0) facings.set(.up, count);
    } else facings.set(.up, 0);

    if (input.held(.down)) {
        dir.y += 1;
        if (facings.get(.down) == 0) facings.set(.down, count);
    } else facings.set(.down, 0);

    if (input.held(.left)) {
        dir.x -= 1;
        if (facings.get(.left) == 0) facings.set(.left, count);
    } else facings.set(.left, 0);

    if (input.held(.right)) {
        dir.x += 1;
        if (facings.get(.right) == 0) facings.set(.right, count);
    } else facings.set(.right, 0);

    var max: u64 = 0;
    var iterator = facings.iterator();
    while (iterator.next()) |entry| {
        if (entry.value.* > max) {
            max = entry.value.*;
            facing = entry.key;
        }
    }
    return dir;
}

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

pub fn cameraLookAt() void {
    const half = window.size.scale(0.5);
    const max = map.size.sub(window.size);
    camera.main.position = position.sub(half).clamp(.zero, max);
}

pub fn collider() math.Rect {
    return math.Rect.init(position, SIZE);
}

pub fn talkCollider() math.Rect {
    return switch (facing) {
        .up => .init(position.addXY(-3, -28), .xy(20, 20)),
        .down => .init(position.addXY(-3, 20), .xy(20, 20)),
        .left => .init(position.addXY(-28, -10), .xy(20, 20)),
        .right => .init(position.addXY(20, -10), .xy(20, 20)),
    };
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

pub fn draw() void {
    zhu.batch.drawImage(animation.subImage(), position.addXY(-10, -28), .{});

    // camera.debugDraw(.init(position, SIZE));
}

pub fn drawTalk() void {
    zhu.batch.drawImage(photo(), .xy(35, 396), .{});

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(name, .xy(25, 445), .{ .color = .yellow });
}

pub fn photo() zhu.Image {
    var down = animation;
    down.source = down.sources[0];
    return down.subImageAt(0);
}

pub fn battleTexture() zhu.Image {
    var right = animation;
    right.source = right.sources[2];
    return right.subImageAt(0);
}

pub fn drawStatus() void {
    const pos = zhu.Vector2.xy(120, 90);
    // 背景
    zhu.batch.drawImage(bgTexture, pos.addXY(-10, -10), .{});

    // 头像
    zhu.batch.drawImage(photo(), pos.addXY(10, 10), .{});
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
