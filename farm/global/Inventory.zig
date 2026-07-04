const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const factory = @import("../factory.zig");
const storage = @import("../storage.zig");

const ItemEnum = component.item.ItemEnum;
const Store = zhu.widget.StackStore(ItemEnum, 40, stackLimit);
const Self = @This();

pub const Stack = Store.Stack;
pub const Item = Stack;
const Move = Store.Move;
pub const Use = union(enum) { none, full, item: Stack };

store: Store = .{},
hotbar: [10]?usize = @splat(null),
activeHotbar: usize = 0,
activePage: usize = 0,

fn stackLimit(itemType: ItemEnum) u32 {
    // 叠加上限由物品配置决定，库存逻辑只执行规则。
    return factory.itemConfig(itemType).limit;
}

pub fn reset(self: *Self) void {
    self.store.clear();
    self.hotbar = @splat(null);
    self.activeHotbar = 0;
    self.activePage = 0;
}

pub fn capture(self: *Self) storage.Inventory {
    return .{
        .activeHotbar = self.activeHotbar,
        .activePage = self.activePage,
        .slots = self.store.stacks[0..],
        .hotbar = self.hotbar[0..],
    };
}

pub fn restore(self: *Self, data: storage.Inventory) void {
    self.reset();
    @memcpy(self.store.stacks[0..], data.slots);
    @memcpy(self.hotbar[0..], data.hotbar);
    self.activeHotbar = data.activeHotbar;
    self.activePage = data.activePage;
}

pub fn add(self: *Self, itemType: ItemEnum, count: u32) u32 {
    const remaining = self.store.add(itemType, count);
    if (remaining < count) self.autoBind(itemType);
    return remaining;
}

pub fn active(self: *Self) ?ItemEnum {
    const index = self.hotbar[self.activeHotbar] orelse return null;
    const stack = self.store.getPtr(index) orelse return null;
    return stack.item;
}

pub fn use(self: *Self, itemType: ItemEnum, count: u32) bool {
    std.debug.assert(count > 0);
    return self.store.subAll(itemType, count);
}

pub fn useAt(self: *Self, index: usize) Use {
    std.debug.assert(index < self.store.stacks.len);

    const slot = self.store.getPtr(index) orelse return .none;
    const cfg = factory.itemConfig(slot.item);
    const effect = cfg.product orelse return .none;
    const product = effect.value;

    if (slot.count == 1) {
        slot.* = product;
        self.autoBind(product.item);
        return .{ .item = slot.* };
    }

    if (!self.store.useAt(index, product)) return .full;

    self.autoBind(product.item);
    return .{ .item = product };
}

pub fn moveSlot(
    self: *Self,
    fromIndex: usize,
    toIndex: usize,
) ?Move {
    if (fromIndex == toIndex) return null;

    const moved = self.store.move(fromIndex, toIndex) orelse return null;
    switch (moved) {
        .swap => self.swapHotbarRefs(fromIndex, toIndex),
        .merge => {},
        .clear => self.replaceHotbarRefs(fromIndex, toIndex),
    }
    return moved;
}

pub fn bindHotbar(
    self: *Self,
    hotbarIndex: usize,
    bagIndex: usize,
) void {
    self.clearHotbarItemRefs(self.store.get(bagIndex).?.item);
    self.hotbar[hotbarIndex] = bagIndex;
}

pub fn clearHotbar(self: *Self, hotbarIndex: usize) void {
    self.hotbar[hotbarIndex] = null;
}

pub fn moveHotbarBinding(
    self: *Self,
    fromIndex: usize,
    toIndex: usize,
) void {
    if (fromIndex == toIndex) return;

    const from = self.hotbar[fromIndex] orelse return;
    self.hotbar[fromIndex] = self.hotbar[toIndex];
    self.hotbar[toIndex] = from;
}

fn autoBind(self: *Self, itemType: ItemEnum) void {
    if (self.hasHotbarItem(itemType)) return;

    const bagIndex = self.store.first(itemType) orelse return;
    const hotbarIndex = self.firstEmptyHotbar() orelse return;
    self.bindHotbar(hotbarIndex, bagIndex);
}

fn clearHotbarItemRefs(self: *Self, itemType: ItemEnum) void {
    for (&self.hotbar) |*slotIndex| {
        const index = slotIndex.* orelse continue;
        const slot = self.store.getPtr(index) orelse continue;
        if (slot.item == itemType) slotIndex.* = null;
    }
}

fn replaceHotbarRefs(
    self: *Self,
    fromIndex: usize,
    toIndex: usize,
) void {
    for (&self.hotbar) |*slotIndex| {
        if (slotIndex.* == fromIndex) slotIndex.* = toIndex;
    }
}

fn swapHotbarRefs(self: *Self, a: usize, b: usize) void {
    for (&self.hotbar) |*slotIndex| {
        const index = slotIndex.* orelse continue;
        if (index == a) slotIndex.* = b;
        if (index == b) slotIndex.* = a;
    }
}

fn hasHotbarItem(self: *Self, itemType: ItemEnum) bool {
    for (self.hotbar) |slotIndex| {
        const index = slotIndex orelse continue;
        const slot = self.store.getPtr(index) orelse continue;
        if (slot.item == itemType) return true;
    }
    return false;
}

fn firstEmptyHotbar(self: *Self) ?usize {
    for (self.hotbar, 0..) |slotIndex, index| {
        const bagIndex = slotIndex orelse return index;
        if (self.store.get(bagIndex) == null) return index;
    }
    return null;
}

test "添加物品会合并并自动绑定快捷栏" {
    var inv: Self = .{};
    inv.reset();

    _ = inv.add(.strawberry, 7);
    _ = inv.add(.strawberry, 3);

    try std.testing.expectEqual(.strawberry, inv.active().?);
    const index = inv.hotbar[inv.activeHotbar].?;
    try std.testing.expectEqual(10, inv.store.stacks[index].count);
}

test "restore 会恢复库存槽和快捷栏" {
    var inv: Self = .{};
    inv.reset();

    var stacks: [40]storage.Item = @splat(.empty);
    stacks[0] = .{ .item = .strawberrySeed, .count = 7 };
    var hotbar: [10]?usize = @splat(null);
    hotbar[3] = 0;
    const data = storage.Inventory{
        .activeHotbar = 3,
        .activePage = 1,
        .slots = &stacks,
        .hotbar = &hotbar,
    };

    inv.restore(data);

    try std.testing.expectEqual(
        component.item.ItemEnum.strawberrySeed,
        inv.active().?,
    );
    const index = inv.hotbar[inv.activeHotbar].?;
    try std.testing.expectEqual(7, inv.store.stacks[index].count);
    try std.testing.expectEqual(0, inv.hotbar[3].?);
    try std.testing.expectEqual(3, inv.activeHotbar);
    try std.testing.expectEqual(1, inv.activePage);
}

test "新增工具会占用独立槽位" {
    var inv: Self = .{};
    inv.reset();

    try std.testing.expectEqual(0, inv.add(.hoe, 1));
    try std.testing.expectEqual(0, inv.add(.hoe, 1));

    try std.testing.expectEqual(.hoe, inv.store.stacks[0].item);
    try std.testing.expectEqual(1, inv.store.stacks[0].count);
    try std.testing.expectEqual(.hoe, inv.store.stacks[1].item);
    try std.testing.expectEqual(1, inv.store.stacks[1].count);
}

test "移动同类工具不会合并" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .hoe, .count = 1 };
    inv.store.stacks[1] = .{ .item = .hoe, .count = 1 };

    _ = inv.moveSlot(0, 1);

    try std.testing.expectEqual(1, inv.store.stacks[0].count);
    try std.testing.expectEqual(1, inv.store.stacks[1].count);
}

test "当前物品通过快捷栏引用读取库存槽" {
    var inv: Self = .{};
    inv.reset();

    inv.activeHotbar = 1;
    inv.store.stacks[5] = .{ .item = .potatoSeed, .count = 2 };
    inv.hotbar[1] = 5;

    try std.testing.expectEqual(.potatoSeed, inv.active().?);
    try std.testing.expectEqual(2, inv.store.stacks[5].count);

    inv.store.stacks[5].count = 0;
    try std.testing.expectEqual(null, inv.active());
}

test "同一种物品只能绑定到一个快捷栏槽位" {
    var inv: Self = .{};
    inv.reset();

    // 快捷栏按物品类型唯一绑定，避免同类物品占用多个快捷键。
    inv.store.stacks[0] = .{ .item = .strawberrySeed, .count = 2 };
    inv.store.stacks[2] = .{ .item = .strawberrySeed, .count = 4 };

    inv.bindHotbar(0, 0);
    inv.bindHotbar(3, 2);

    try std.testing.expectEqual(null, inv.hotbar[0]);
    try std.testing.expectEqual(2, inv.hotbar[3].?);
}

test "快捷栏拖到空快捷栏会移动绑定" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    inv.bindHotbar(0, 0);

    inv.moveHotbarBinding(0, 4);

    try std.testing.expectEqual(null, inv.hotbar[0]);
    try std.testing.expectEqual(0, inv.hotbar[4].?);
}

test "快捷栏拖到已有快捷栏会交换绑定" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    inv.store.stacks[1] = .{ .item = .potato, .count = 3 };
    inv.bindHotbar(0, 0);
    inv.bindHotbar(4, 1);

    inv.moveHotbarBinding(0, 4);

    try std.testing.expectEqual(1, inv.hotbar[0].?);
    try std.testing.expectEqual(0, inv.hotbar[4].?);
}

test "拖动物品到空槽后快捷栏继续指向该物品" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    inv.bindHotbar(2, 0);
    inv.activeHotbar = 2;

    _ = inv.moveSlot(0, 5);

    try std.testing.expectEqual(.strawberry, inv.active().?);
    try std.testing.expectEqual(5, inv.store.stacks[5].count);
}

test "交换不同物品后快捷栏继续指向原物品" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    inv.store.stacks[1] = .{ .item = .potato, .count = 3 };
    inv.bindHotbar(0, 0);
    inv.bindHotbar(1, 1);

    _ = inv.moveSlot(0, 1);

    inv.activeHotbar = 0;
    try std.testing.expectEqual(.strawberry, inv.active().?);
    try std.testing.expectEqual(5, inv.store.stacks[inv.hotbar[0].?].count);

    inv.activeHotbar = 1;
    try std.testing.expectEqual(.potato, inv.active().?);
    try std.testing.expectEqual(3, inv.store.stacks[inv.hotbar[1].?].count);
}

test "合并同类物品后快捷栏继续指向合并物品" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    inv.store.stacks[1] = .{ .item = .strawberry, .count = 4 };
    inv.bindHotbar(0, 0);
    inv.activeHotbar = 0;

    _ = inv.moveSlot(0, 1);

    try std.testing.expectEqual(.strawberry, inv.active().?);
    try std.testing.expectEqual(9, inv.store.stacks[inv.hotbar[0].?].count);
}

test "使用作物会消耗一个并产出种子" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 2 };

    const result = inv.useAt(0);

    try std.testing.expectEqual(.strawberry, inv.store.stacks[0].item);
    try std.testing.expectEqual(1, inv.store.stacks[0].count);
    try std.testing.expectEqual(.strawberrySeed, inv.store.stacks[1].item);
    try std.testing.expectEqual(3, inv.store.stacks[1].count);

    const item = switch (result) {
        .item => |value| value,
        .none, .full => return error.TestExpectedEqual,
    };
    try std.testing.expectEqual(.strawberrySeed, item.item);
    try std.testing.expectEqual(3, item.count);
}

test "使用最后一个作物会优先回填原槽" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .potato, .count = 1 };
    inv.hotbar[0] = 0;

    const result = inv.useAt(0);

    try std.testing.expectEqual(.potatoSeed, inv.store.stacks[0].item);
    try std.testing.expectEqual(3, inv.store.stacks[0].count);
    try std.testing.expectEqual(0, inv.hotbar[0].?);
    try std.testing.expectEqual(.potatoSeed, inv.active().?);

    const item = switch (result) {
        .item => |value| value,
        .none, .full => return error.TestExpectedEqual,
    };
    try std.testing.expectEqual(.potatoSeed, item.item);
    try std.testing.expectEqual(3, item.count);
}

test "use 会在数量足够时扣除指定物品" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberrySeed, .count = 2 };

    try std.testing.expect(!inv.use(.potatoSeed, 1));
    try std.testing.expectEqual(@as(u32, 2), inv.store.stacks[0].count);

    try std.testing.expect(inv.use(.strawberrySeed, 1));
    try std.testing.expectEqual(@as(u32, 1), inv.store.stacks[0].count);

    try std.testing.expect(!inv.use(.strawberrySeed, 2));
    try std.testing.expectEqual(@as(u32, 1), inv.store.stacks[0].count);
}

test "use 会先确认总数足够再跨槽扣除" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberrySeed, .count = 1 };
    inv.store.stacks[2] = .{ .item = .strawberrySeed, .count = 2 };

    try std.testing.expect(!inv.use(.strawberrySeed, 4));
    try std.testing.expectEqual(@as(u32, 1), inv.store.stacks[0].count);
    try std.testing.expectEqual(@as(u32, 2), inv.store.stacks[2].count);

    try std.testing.expect(inv.use(.strawberrySeed, 3));
    try std.testing.expectEqual(@as(u32, 0), inv.store.stacks[0].count);
    try std.testing.expectEqual(@as(u32, 0), inv.store.stacks[2].count);
}

test "使用物品产物优先回到原槽而不是第一个空槽" {
    var inv: Self = .{};
    inv.reset();

    inv.store.stacks[5] = .{ .item = .potato, .count = 1 };

    const result = inv.useAt(5);

    try std.testing.expectEqual(0, inv.store.stacks[0].count);
    try std.testing.expectEqual(.potatoSeed, inv.store.stacks[5].item);
    try std.testing.expectEqual(3, inv.store.stacks[5].count);

    const item = switch (result) {
        .item => |value| value,
        .none, .full => return error.TestExpectedEqual,
    };
    try std.testing.expectEqual(.potatoSeed, item.item);
    try std.testing.expectEqual(3, item.count);
}

test "使用物品空间不足时不会修改背包" {
    var inv: Self = .{};
    inv.reset();

    @memset(&inv.store.stacks, .{ .item = .potato, .count = 99 });
    inv.store.stacks[0] = .{ .item = .strawberry, .count = 2 };

    const result = inv.useAt(0);

    try std.testing.expectEqual(Use.full, result);
    try std.testing.expectEqual(.strawberry, inv.store.stacks[0].item);
    try std.testing.expectEqual(2, inv.store.stacks[0].count);
    try std.testing.expectEqual(.potato, inv.store.stacks[1].item);
    try std.testing.expectEqual(99, inv.store.stacks[1].count);
}
