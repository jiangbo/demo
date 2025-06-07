const std = @import("std");

const gfx = @import("../graphics.zig");

pub const Item = struct {
    info: *ItemInfo,
    count: u32 = 0,
};

pub const ItemInfo = struct {
    name: []const u8 = &.{},
    texture: gfx.Texture,
    tip: []const u8 = &.{},
    price: u32 = 0,
    value1: u32 = 0,
    value2: u32 = 0,
    value3: u32 = 0,
    value4: u32 = 0,
    value5: u32 = 0,

    pub fn addValue(self: *ItemInfo, other: *const ItemInfo) void {
        self.value2 += other.value2;
        self.value3 += other.value3;
        self.value4 += other.value4;
        self.value5 += other.value5;
    }
};

pub var infos: [8]ItemInfo = undefined;

pub var money: u32 = 143;
pub var items: [10]Item = undefined;
pub var skills: [10]Item = undefined;

pub fn init() void {
    initInfos();

    for (&items) |*item| item.count = 0;

    items[0] = .{ .info = &infos[0], .count = 2 };
    items[1] = .{ .info = &infos[1], .count = 3 };

    items[2] = .{ .info = &infos[2], .count = 2 };

    for (&skills) |*skill| skill.count = 0;

    skills[0] = .{ .info = &infos[6], .count = 20 };
    skills[1] = .{ .info = &infos[7], .count = 20 };
}

fn initInfos() void {
    infos[0] = .{
        .name = "红药水",
        .texture = gfx.loadTexture("assets/item/item1.png", .init(66, 66)),
        .tip = "恢复少量 HP",
        .price = 30,
    };
    infos[1] = .{
        .name = "蓝药水",
        .texture = gfx.loadTexture("assets/item/item2.png", .init(66, 66)),
        .tip = "恢复少量 MP",
        .price = 200,
    };
    infos[2] = .{
        .name = "短剑",
        .texture = gfx.loadTexture("assets/item/item3.png", .init(66, 66)),
        .tip = "一把钢制短剑",
        .price = 100,
        .value1 = 1,
        .value2 = 10,
        .value5 = 5,
    };
    infos[3] = .{
        .name = "斧头",
        .texture = gfx.loadTexture("assets/item/item4.png", .init(66, 66)),
        .tip = "传说这是一把能够劈开阴\n气的斧头，但无人亲眼见n过它的威力",
        .price = 100,
        .value1 = 1,
        .value2 = 3,
        .value5 = 50,
    };
    infos[4] = .{
        .name = "钢盾",
        .texture = gfx.loadTexture("assets/item/item5.png", .init(66, 66)),
        .tip = "钢质盾牌，没有矛可以穿\n破它",
        .price = 100,
        .value1 = 2,
        .value3 = 20,
        .value4 = 5,
    };
    infos[5] = .{
        .name = "魔法书",
        .texture = gfx.loadTexture("assets/item/item6.png", .init(66, 66)),
        .tip = "一本游记，记录世间\n奇事，可打开阅览",
        .price = 100,
    };

    infos[6] = .{
        .name = "治疗术",
        .texture = gfx.loadTexture("assets/item/skill1.png", .init(66, 66)),
        .tip = "恢复少量 HP",
        .price = 20,
    };

    infos[7] = .{
        .name = "黑洞漩涡",
        .texture = gfx.loadTexture("assets/item/skill2.png", .init(66, 66)),
        .tip = "攻击型技能，\n将敌人吸入漩涡",
        .price = 20,
    };
}
