const std = @import("std");

const zhu = @import("zhu");
const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const math = zhu.math;

const item = @import("item.zig");

const FrameAnimation = gfx.FixedFrameAnimation(3, 0.15);
const Animation = std.EnumArray(math.FourDirection, FrameAnimation);

const name = "小飞刀";
const MOVE_SPEED = 100;
var texture: gfx.Texture = undefined;
var animation: Animation = undefined;

var moving: bool = false;
var direction: math.Vector = .zero;
pub var position: math.Vector = undefined;

pub var money: usize = 50; // 金钱
pub var items: [16]u16 = undefined;
var itemIndex: usize = 0;

var level: usize = 1; //等级
var exp: usize = 0; //经验
var maxExp: usize = 100; //经验最大值
var health: usize = 50; //生命
var maxHealth: usize = 50; //生命最大值
var attack: usize = 10; //攻击
var defend: usize = 10; //防御
var speed: usize = 8; //速度

var bgTexture: gfx.Texture = undefined;
var itemTexture: gfx.Texture = undefined;

pub fn init() void {
    texture = gfx.loadTexture("assets/pic/player.png", .init(96, 192));
    bgTexture = gfx.loadTexture("assets/pic/sbar.png", .init(420, 320));
    itemTexture = gfx.loadTexture("assets/pic/goods.png", .init(384, 192));

    animation = Animation.initUndefined();

    var tex = texture.subTexture(.init(.zero, .init(96, 48)));
    animation.set(.down, FrameAnimation.init(tex));

    tex = texture.subTexture(tex.area.move(.init(0, 48)));
    animation.set(.left, FrameAnimation.init(tex));

    tex = texture.subTexture(tex.area.move(.init(0, 48)));
    animation.set(.right, FrameAnimation.init(tex));

    tex = texture.subTexture(tex.area.move(.init(0, 48)));
    animation.set(.up, FrameAnimation.init(tex));

    @memset(&items, 0);
}

pub fn update(delta: f32) void {
    if (moving) animation.getPtr(facing()).update(delta);
}

pub fn updateItem() void {
    if (window.isAnyKeyRelease(&.{ .LEFT, .A })) {
        itemIndex -|= 1;
    }

    if (window.isAnyKeyRelease(&.{ .RIGHT, .D })) {
        itemIndex += 1;
        if (itemIndex >= items.len) itemIndex = items.len - 1;
    }

    if (window.isAnyKeyRelease(&.{ .DOWN, .S })) {
        itemIndex = (itemIndex + items.len / 2) % items.len;
    }

    if (window.isAnyKeyRelease(&.{ .UP, .W })) {
        itemIndex = (itemIndex + items.len / 2 * 3) % items.len;
    }
}

pub fn toMove(delta: f32) ?math.Vector {
    var dir = math.Vector.zero;
    if (window.isAnyKeyDown(&.{ .UP, .W })) dir.y -= 1;
    if (window.isAnyKeyDown(&.{ .DOWN, .S })) dir.y += 1;
    if (window.isAnyKeyDown(&.{ .LEFT, .A })) dir.x -= 1;
    if (window.isAnyKeyDown(&.{ .RIGHT, .D })) dir.x += 1;

    moving = dir.x != 0 or dir.y != 0;
    if (moving) {
        direction = dir.normalize().scale(MOVE_SPEED);
        return position.add(direction.scale(delta));
    } else return null;
}

pub fn addItem(itemId: u16) void {
    for (&items) |*value| {
        if (value.* == 0) {
            value.* = itemId;
            return;
        }
    }
}

pub fn render() void {
    const current = animation.get(facing());
    camera.drawOption(current.currentTexture(), position, .{
        .pivot = .init(0.5, 0.9),
    });

    // camera.debugDraw(.init(position.addXY(-8, -12), .init(16, 14)));
}

pub fn facing() math.FourDirection {
    if (@abs(direction.x) > @abs(direction.y))
        return if (direction.x < 0) .left else .right
    else
        return if (direction.y < 0) .up else .down;
}

pub fn renderTalk() void {

    // 头像
    const down = animation.get(.down);
    const tex = down.texture.subTexture(down.frames[0]);
    camera.draw(tex, .init(30, 396));

    // 名字
    const nameColor = gfx.color(1, 1, 0, 1);
    camera.drawColorText(name, .init(18, 445), nameColor);
}

pub fn renderStatus() void {
    const pos = gfx.Vector.init(120, 90);
    // 背景
    camera.draw(bgTexture, pos.addXY(-10, -10));

    // 头像
    const down = animation.get(.down);
    const tex = down.texture.subTexture(down.frames[0]);
    camera.draw(tex, pos.addXY(10, 10));

    // 等级
    camera.drawColorText("等级：", pos.addXY(122, 52), .{ .w = 1 });
    camera.drawText("等级：", pos.addXY(120, 50));
    camera.drawColorNumber(level, pos.addXY(232, 52), .{ .w = 1 });
    camera.drawNumber(level, pos.addXY(230, 50));

    // 经验
    camera.drawColorText("经验：", pos.addXY(122, 82), .{ .w = 1 });
    camera.drawText("经验：", pos.addXY(120, 80));
    var buffer: [30]u8 = undefined;
    const expStr = zhu.format(&buffer, "{d}/{d}", .{ exp, maxExp });
    camera.drawColorText(expStr, pos.addXY(232, 82), .{ .w = 1 });
    camera.drawText(expStr, pos.addXY(230, 80));

    // 生命
    camera.drawColorText("生命：", pos.addXY(122, 112), .{ .w = 1 });
    camera.drawText("生命：", pos.addXY(120, 110));
    const healthStr = zhu.format(&buffer, "{d}/{d}", .{ health, maxHealth });
    camera.drawColorText(healthStr, pos.addXY(232, 112), .{ .w = 1 });
    camera.drawText(healthStr, pos.addXY(230, 110));

    // 攻击
    camera.drawColorText("攻击：", pos.addXY(122, 142), .{ .w = 1 });
    camera.drawText("攻击：", pos.addXY(120, 140));
    camera.drawColorNumber(attack, pos.addXY(232, 142), .{ .w = 1 });
    camera.drawNumber(attack, pos.addXY(230, 140));

    // 防御
    camera.drawColorText("防御：", pos.addXY(122, 172), .{ .w = 1 });
    camera.drawText("防御：", pos.addXY(120, 170));
    camera.drawColorNumber(defend, pos.addXY(232, 172), .{ .w = 1 });
    camera.drawNumber(defend, pos.addXY(230, 170));

    // 速度
    camera.drawColorText("速度：", pos.addXY(122, 202), .{ .w = 1 });
    camera.drawText("速度：", pos.addXY(120, 200));
    camera.drawColorNumber(speed, pos.addXY(232, 202), .{ .w = 1 });
    camera.drawNumber(speed, pos.addXY(230, 200));

    // 金币
    camera.drawColorText("金币：", pos.addXY(122, 232), .{ .w = 1 });
    camera.drawColorText("金币：", pos.addXY(120, 230), gfx.color(1, 1, 0, 1));
    camera.drawColorNumber(money, pos.addXY(232, 230), .{ .w = 1 });
    camera.drawColorNumber(money, pos.addXY(230, 230), gfx.color(1, 1, 0, 1));
}

pub fn renderItem() void {
    const pos = gfx.Vector.init(120, 90);
    camera.draw(bgTexture, pos.addXY(-10, -10));

    // 当前选中物品
    var buffer: [32]u8 = undefined;
    if (items[itemIndex] != 0) {
        const current = item.items[items[itemIndex]];

        camera.drawText(current.name, pos.addXY(70, 20));
        camera.drawText(" (价值：", pos.addXY(180, 20));
        const text = zhu.format(&buffer, "{d}）", .{current.money});
        camera.drawText(text, pos.addXY(260, 20));

        camera.drawText("经验：", pos.addXY(20, 60));
        camera.drawNumber(current.exp, pos.addXY(100, 60));

        camera.drawText("生命：", pos.addXY(20, 86));
        camera.drawNumber(current.health, pos.addXY(100, 86));

        camera.drawText("攻击：", pos.addXY(20, 112));
        camera.drawNumber(current.attack, pos.addXY(100, 112));

        camera.drawText("防御：", pos.addXY(20, 134));
        camera.drawNumber(current.defend, pos.addXY(100, 134));

        // 描述
        const color = gfx.color(1, 1, 0, 1);
        camera.drawColorText(current.about, pos.addXY(170, 60), color);
    }

    const itemBg = getItemIconFromIndex(0);
    const itemSelected = getItemIconFromIndex(1);

    const offset = pos.addXY(5, 170);

    for (0..2) |i| {
        const row: f32 = @floatFromInt(i);
        for (0..8) |j| {
            const col: f32 = @floatFromInt(j);
            const itemPos = offset.addXY(col * 49, row * 49);
            camera.draw(itemBg, itemPos);

            const index = j + 8 * i;
            defer if (itemIndex == index) camera.draw(itemSelected, itemPos);
            if (items[index] == 0) continue;

            camera.draw(getItemIconFromIndex(items[index]), itemPos);
        }
    }
    // 金币，操作说明
    camera.drawText("（金=", pos.addXY(10, 270));
    const moneyStr = zhu.format(&buffer, "{d}）", .{money});
    camera.drawText(moneyStr, pos.addXY(60, 270));
    camera.drawText("CTRL=使用‘A’=丢弃 ESC=退出", pos.addXY(118, 270));
}

fn getItemIconFromIndex(index: usize) gfx.Texture {
    const row: f32 = @floatFromInt(index / 8);
    const col: f32 = @floatFromInt(index % 8);
    const pos = gfx.Vector.init(col * 48, row * 48);
    return itemTexture.subTexture(.init(pos, .init(48, 48)));
}
