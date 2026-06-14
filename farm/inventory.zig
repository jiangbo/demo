const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");

const ItemEnum = component.item.ItemEnum;
const NineOption = zhu.batch.NineOption;
const ImageId = zhu.graphics.ImageId;

const NineImage = struct { rect: zhu.Rect, nine: NineOption };

const HotbarZon = struct {
    imageId: ImageId,
    rect: zhu.Rect,
    slotSize: zhu.Vector2,
    slots: [10]zhu.Vector2,
    panel: NineImage,
    slot: NineImage,
    selected: NineImage,
};

const InventoryZon = struct {
    imageId: ImageId,
    rect: zhu.Rect,
    pageCount: usize,
    slotSize: zhu.Vector2,
    slots: [20]zhu.Vector2,
    prev: zhu.Rect,
    next: zhu.Rect,
    pageText: zhu.Vector2,
    panel: NineImage,
    slot: NineImage,
};

const Zon = struct { hotbar: HotbarZon, inventory: InventoryZon };

pub const Stack = struct { type: ItemEnum = .hoe, count: u32 = 0 };
pub const Item = Stack;

const zon: Zon = @import("zon/inventory.zon");
const pageSize = zon.inventory.slots.len;
const slotCount = pageSize * zon.inventory.pageCount;
const hotbarRect = zon.hotbar.rect;
const inventoryRect = zon.inventory.rect;
const hotbarPosition = hotbarRect.min;
const inventoryPosition = inventoryRect.min;

const Hover = union(enum) { body, slot: usize, prev, next };

pub var slots: [slotCount]Stack = @splat(.{});
pub var hotbar: [zon.hotbar.slots.len]?usize = @splat(null);
pub var activeHotbar: usize = 0;
pub var activePage: usize = 0;
pub var open: bool = false;

var hotbarClick: zhu.widget.Click = .empty;
var inventoryClick: zhu.widget.ClickT(Hover) = .empty;

pub fn reset() void {
    slots = @splat(.{});
    hotbar = @splat(null);
    activeHotbar = 0;
    activePage = 0;
    open = false;

    hotbarClick = .empty;
    inventoryClick = .empty;
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
    if (context.input.pressed(.inventory)) open = !open;

    if (context.input.hotbarIndexPressed()) |index| {
        activeHotbar = index;
    }

    if (hotbarClick.update(hoveredHotbarSlot())) |index| {
        activeHotbar = index;
        zhu.audio.playSound("assets/audio/UI_button08.ogg");
    }

    if (open) updateInventoryPanel() else inventoryClick = .empty;

    if (hotbarClick.captured or inventoryClick.captured) {
        context.input.mouseCaptured = true;
    }
}

fn updateInventoryPanel() void {
    const clicked = inventoryClick.update(hoveredInventory());
    activePage = switch (clicked orelse return) {
        .prev => activePage -| 1,
        .next => @min(activePage + 1, zon.inventory.pageCount - 1),
        .body, .slot => return,
    };
}

fn hoveredHotbarSlot() ?usize {
    const slotRect = zhu.Rect.init(.zero, zon.hotbar.slotSize);
    for (zon.hotbar.slots, 0..) |offset, i| {
        const rect = slotRect.move(hotbarPosition.add(offset));
        if (rect.contains(zhu.window.mouse)) return i;
    }
    return null;
}

fn hoveredInventory() ?Hover {
    if (!inventoryRect.contains(zhu.window.mouse)) return null;

    const mouse = zhu.window.mouse.sub(inventoryPosition);
    const slotRect = zhu.Rect.init(.zero, zon.inventory.slotSize);
    for (zon.inventory.slots, 0..) |offset, i| {
        const rect = slotRect.move(offset);
        if (rect.contains(mouse)) return .{ .slot = i };
    }

    if (zon.inventory.prev.contains(mouse)) return .prev;
    if (zon.inventory.next.contains(mouse)) return .next;
    return .body;
}

pub fn draw() void {
    if (open) drawInventoryPanel();
    drawHotbar();
}

fn drawHotbar() void {
    const panelImage = zhu.assets.getImage(zon.hotbar.imageId).?;
    // 绘制面板
    var image = panelImage.sub(zon.hotbar.panel.rect);
    zhu.batch.drawNine(image, hotbarRect, zon.hotbar.panel.nine);

    for (hotbar, zon.hotbar.slots, 0..) |slotIndex, offset, i| {
        const position = hotbarPosition.add(offset);
        const rect = zhu.Rect.init(position, zon.hotbar.slotSize);
        // 绘制槽位
        image = panelImage.sub(zon.hotbar.slot.rect);
        zhu.batch.drawNine(image, rect, zon.hotbar.slot.nine);

        if (i == activeHotbar) {
            image = panelImage.sub(zon.hotbar.selected.rect);
            zhu.batch.drawNine(image, rect, zon.hotbar.selected.nine);
        }

        const slot = slots[slotIndex orelse continue];
        if (slot.count == 0) continue;

        const iconSize = factory.itemConfig(slot.type).icon.size;
        drawItemIcon(slot.type, rect.center(), iconSize);
        if (slot.count > 1) drawItemCount(slot.count, rect);
    }
}

fn drawInventoryPanel() void {
    const inv = zon.inventory;
    const inventoryImage = zhu.assets.getImage(inv.imageId).?;
    var image = inventoryImage.sub(inv.panel.rect);
    zhu.batch.drawNine(image, inventoryRect, inv.panel.nine);

    const first = activePage * pageSize;
    for (inv.slots, 0..) |offset, i| {
        const position = inventoryPosition.add(offset);
        const slotRect = zhu.Rect.init(position, inv.slotSize);
        image = inventoryImage.sub(inv.slot.rect);
        zhu.batch.drawNine(image, slotRect, inv.slot.nine);

        const slot = slots[first + i];
        if (slot.count == 0) continue;

        const iconSize = factory.itemConfig(slot.type).icon.size;
        drawItemIcon(slot.type, slotRect.center(), iconSize);
        if (slot.count > 1) drawItemCount(slot.count, slotRect);
    }

    drawPageButton(inv.prev, "<");
    drawPageButton(inv.next, ">");

    const labelPos = inventoryPosition.add(inv.pageText);
    const args = .{ activePage + 1, inv.pageCount };
    zhu.text.drawFmt("{d}/{d}", args, labelPos, .{ .alignment = .center });
}

fn drawPageButton(buttonRect: zhu.Rect, label: []const u8) void {
    const inv = zon.inventory;
    const rect = buttonRect.move(inventoryPosition);
    const invImage = zhu.assets.getImage(inv.imageId).?;

    const image = invImage.sub(inv.slot.rect);
    zhu.batch.drawNine(image, rect, inv.slot.nine);
    zhu.text.draw(label, rect.center(), .{ .alignment = .center });
}

fn drawItemIcon(itemType: ItemEnum, position: zhu.Vector2, size: zhu.Vector2) void {
    const image = factory.resolveImage(factory.itemConfig(itemType).icon);
    zhu.batch.drawImage(image, position, .{ .size = size, .anchor = .center });
}

fn drawItemCount(count: u32, rect: zhu.Rect) void {
    const pos = rect.max().sub(.square(1));
    zhu.text.drawFmt("{d}", .{count}, pos, .{ .alignment = .one });
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
