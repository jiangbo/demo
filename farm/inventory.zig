const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");

const ItemEnum = component.item.ItemEnum;
const NineOption = zhu.batch.NineOption;
const ImageId = zhu.graphics.ImageId;

const NineImage = struct { rect: zhu.Rect, nine: NineOption };

const Config = struct {
    imageId: ImageId,
    slotSize: f32,
    spacing: f32,
    slotCount: u32,
    panelPadding: f32,
    bottomMargin: f32,
    panel: NineImage,
    slot: NineImage,
    selected: NineImage,
};

pub const Stack = struct { type: ItemEnum = .hoe, count: u32 = 0 };
pub const Item = Stack;

const zon: Config = @import("zon/preset.zon");

pub var slots: [40]Stack = @splat(.{});
pub var hotbar: [zon.slotCount]?usize = @splat(null);
pub var activeHotbar: usize = 0;
pub var activePage: usize = 0;

var panelPosition: zhu.Vector2 = undefined; // 初始位置
var click: zhu.widget.Click = .empty;
const slotWidth: f32 = zon.slotCount * (zon.slotSize + zon.spacing);
const panelWidth: f32 = slotWidth - zon.spacing + zon.panelPadding * 2;
const panelHeight: f32 = zon.panelPadding * 2 + zon.slotSize;

pub fn reset() void {
    slots = @splat(.{});
    hotbar = @splat(null);
    activeHotbar = 0;
    activePage = 0;

    panelPosition = zhu.Vector2{
        .x = (zhu.window.size.x - panelWidth) / 2,
        .y = zhu.window.size.y - panelHeight - zon.bottomMargin,
    };
    click = .empty;
}

pub fn add(itemType: ItemEnum, count: u32) void {
    const config = factory.itemConfig(itemType);

    var remaining: u32 = count;
    for (&slots) |*slot| { // 先尝试叠加到已有的同类型物品上。
        if (slot.count == 0 or slot.type != itemType) continue;

        const space = config.limit - slot.count;
        if (space == 0) continue;
        const minCount = @min(space, remaining);
        slot.count += minCount;
        remaining -= minCount;
        if (remaining == 0) break;
    }

    for (&slots) |*slot| { // 再尝试放到空槽位。
        if (slot.count > 0 or remaining == 0) continue;

        const minCount = @min(config.limit, remaining);
        slot.* = .{ .type = itemType, .count = minCount };
        remaining -= minCount;
    }

    autoBind(itemType);
}

pub fn active() ?*Stack {
    const index = hotbar[activeHotbar] orelse return null;
    if (slots[index].count == 0) return null;
    return &slots[index];
}

pub fn update() void {
    if (context.input.toolbarIndexPressed()) |index| {
        activeHotbar = index;
    }

    if (click.update(hoveredSlot())) |index| {
        activeHotbar = index;
        zhu.audio.playSound("assets/audio/UI_button08.ogg");
    }

    if (click.captured) context.input.mouseCaptured = true;
}

fn hoveredSlot() ?usize {
    const start = panelPosition.add(.square(zon.panelPadding));
    for (0..hotbar.len) |i| {
        const position = slotPosition(@floatFromInt(i), start);
        const rect = zhu.Rect.init(position, .square(zon.slotSize));
        if (!rect.contains(zhu.window.mouse)) continue;

        return i;
    }
    return null;
}

fn slotPosition(index: f32, position: zhu.Vector2) zhu.Vector2 {
    return position.addX(index * (zon.slotSize + zon.spacing));
}

pub fn draw() void {
    const panelImage = zhu.assets.getImage(zon.imageId).?;
    { // 绘制面板
        const rect = zhu.Rect{
            .min = panelPosition,
            .size = .xy(panelWidth, panelHeight),
        };
        const image = panelImage.sub(zon.panel.rect);
        zhu.batch.drawNine(image, rect, zon.panel.nine);
    }

    const start = panelPosition.add(.square(zon.panelPadding));
    for (hotbar, 0..) |slotIndex, i| {
        const position = slotPosition(@floatFromInt(i), start);
        { // 绘制槽位
            const image = panelImage.sub(zon.slot.rect);
            const rect = zhu.Rect.init(position, .square(zon.slotSize));
            zhu.batch.drawNine(image, rect, zon.slot.nine);
        }

        if (slotIndex) |index| {
            const slot = slots[index];
            if (slot.count == 0) continue;

            const iconSize = factory.itemConfig(slot.type).icon.size;
            const iconOffset = zon.slotSize - iconSize.x;
            const iconPosition = position.add(.square(@round(iconOffset / 2)));

            drawItemIcon(slot.type, iconPosition, iconSize);

            if (slot.count > 1) drawItemCount(slot.count, iconPosition, iconSize);
        }

        if (i == activeHotbar) {
            const image = panelImage.sub(zon.selected.rect);
            const rect = zhu.Rect.init(position, .square(zon.slotSize));
            zhu.batch.drawNine(image, rect, zon.selected.nine);
        }
    }
}

fn drawItemIcon(itemType: ItemEnum, position: zhu.Vector2, size: zhu.Vector2) void {
    const image = factory.resolveImage(factory.itemConfig(itemType).icon);
    zhu.batch.drawImage(image, position, .{ .size = size });
}

fn drawItemCount(count: u32, position: zhu.Vector2, size: zhu.Vector2) void {
    const pos = position.add(size).sub(.square(1));
    zhu.text.drawFormat("{d}", pos, .{count}, .{ .alignment = .one });
}

fn autoBind(itemType: ItemEnum) void {
    if (itemOnHotbar(itemType)) return;

    const inventoryIndex = firstInventorySlot(itemType) orelse return;
    const hotbarIndex = firstEmptyHotbar() orelse return;
    hotbar[hotbarIndex] = inventoryIndex;
}

fn itemOnHotbar(itemType: ItemEnum) bool {
    for (hotbar) |slotIndex| {
        const index = slotIndex orelse continue;
        const slot = slots[index];
        if (slot.count > 0 and slot.type == itemType) return true;
    }
    return false;
}

fn firstInventorySlot(itemType: ItemEnum) ?usize {
    for (slots, 0..) |slot, index| {
        if (slot.count > 0 and slot.type == itemType) return index;
    }
    return null;
}

fn firstEmptyHotbar() ?usize {
    for (hotbar, 0..) |slotIndex, index| {
        const inventoryIndex = slotIndex orelse return index;
        if (slots[inventoryIndex].count == 0) return index;
    }
    return null;
}

test "添加物品会合并并自动绑定快捷栏" {
    const oldSlots = slots;
    const oldHotbar = hotbar;
    const oldActiveHotbar = activeHotbar;
    const oldActivePage = activePage;
    defer {
        slots = oldSlots;
        hotbar = oldHotbar;
        activeHotbar = oldActiveHotbar;
        activePage = oldActivePage;
    }

    slots = @splat(.{});
    hotbar = @splat(null);
    activeHotbar = 0;
    activePage = 0;

    add(.strawberry, 7);
    add(.strawberry, 3);

    try std.testing.expectEqual(ItemEnum.strawberry, slots[0].type);
    try std.testing.expectEqual(10, slots[0].count);
    try std.testing.expectEqual(0, hotbar[0].?);
}

test "添加物品超过堆叠上限会填入下一个库存槽" {
    const oldSlots = slots;
    const oldHotbar = hotbar;
    const oldActiveHotbar = activeHotbar;
    const oldActivePage = activePage;
    defer {
        slots = oldSlots;
        hotbar = oldHotbar;
        activeHotbar = oldActiveHotbar;
        activePage = oldActivePage;
    }

    slots = @splat(.{});
    hotbar = @splat(null);
    activeHotbar = 0;
    activePage = 0;

    add(.strawberry, 100);

    try std.testing.expectEqual(99, slots[0].count);
    try std.testing.expectEqual(1, slots[1].count);
    try std.testing.expectEqual(0, hotbar[0].?);
    try std.testing.expectEqual(null, hotbar[1]);
}

test "当前物品通过快捷栏引用读取库存槽" {
    const oldSlots = slots;
    const oldHotbar = hotbar;
    const oldActiveHotbar = activeHotbar;
    const oldActivePage = activePage;
    defer {
        slots = oldSlots;
        hotbar = oldHotbar;
        activeHotbar = oldActiveHotbar;
        activePage = oldActivePage;
    }

    slots = @splat(.{});
    hotbar = @splat(null);
    activeHotbar = 1;
    activePage = 0;
    slots[5] = .{ .type = .potatoSeed, .count = 2 };
    hotbar[1] = 5;

    try std.testing.expectEqual(ItemEnum.potatoSeed, active().?.type);
    try std.testing.expectEqual(2, active().?.count);

    slots[5].count = 0;
    try std.testing.expectEqual(null, active());
}
