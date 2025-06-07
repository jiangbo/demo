const std = @import("std");

const gfx = @import("../graphics.zig");

pub const Item = struct {
    name: []const u8 = &.{},
    count: u32 = 0,
    texture: gfx.Texture,
    tip: []const u8 = &.{},
    value1: u32 = 0,
    value2: u32 = 0,
    value3: u32 = 0,
    value4: u32 = 0,
    value5: u32 = 0,

    pub fn addValue(self: *Item, other: *const Item) void {
        self.value2 += other.value2;
        self.value3 += other.value3;
        self.value4 += other.value4;
        self.value5 += other.value5;
    }
};

pub var money: u32 = 143;
pub var items: [10]Item = undefined;
pub var skills: [10]Item = undefined;

pub fn init() void {
    for (&items) |*item| item.count = 0;

    items[0] = .{
        .name = "红药水",
        .texture = gfx.loadTexture("assets/item/item1.png", .init(66, 66)),
        .tip = "恢复少量 HP",
        .count = 2,
    };

    items[1] = .{
        .name = "蓝药水",
        .texture = gfx.loadTexture("assets/item/item2.png", .init(66, 66)),
        .tip = "恢复少量 MP",
        .count = 3,
    };

    items[2] = .{
        .name = "短剑",
        .texture = gfx.loadTexture("assets/item/item3.png", .init(66, 66)),
        .tip = "一把钢制短剑",
        .count = 2,
        .value1 = 1,
        .value2 = 5,
        .value4 = 1,
    };

    for (&skills) |*skill| skill.count = 0;

    skills[0] = .{
        .name = "治疗术",
        .texture = gfx.loadTexture("assets/item/skill1.png", .init(66, 66)),
        .tip = "恢复少量 HP",
        .count = 20,
    };

    skills[1] = .{
        .name = "黑洞漩涡",
        .texture = gfx.loadTexture("assets/item/skill2.png", .init(66, 66)),
        .tip = "攻击型技能，将敌人吸入漩涡",
        .count = 20,
    };
}
