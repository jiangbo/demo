const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");

const ItemEnum = component.item.ItemEnum;
const ImageId = zhu.graphics.ImageId;

const NineSource = zhu.NineImage.Source;

const HotbarZon = struct {
    imageId: ImageId,
    position: zhu.Vector2,
    size: zhu.Vector2,
    slotSize: zhu.Vector2,
    slots: [10]zhu.Vector2,
    panel: NineSource,
    slot: NineSource,
    selected: NineSource,
};

const InventoryZon = struct {
    imageId: ImageId,
    position: zhu.Vector2,
    size: zhu.Vector2,
    pageCount: usize,
    slotSize: zhu.Vector2,
    slots: [20]zhu.Vector2,
    prev: zhu.Rect,
    next: zhu.Rect,
    pageText: zhu.Vector2,
    panel: NineSource,
    slot: NineSource,
};

const Zon = struct { hotbar: HotbarZon, inventory: InventoryZon };

pub const Stack = struct { type: ItemEnum = .hoe, count: u32 = 0 };
pub const Item = Stack;

const zon: Zon = @import("zon/inventory.zon");
const pageSize = zon.inventory.slots.len;
const slotCount = pageSize * zon.inventory.pageCount;

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
    const mouse = zhu.window.mouse.sub(zon.hotbar.position);
    const slotRect = zhu.Rect.init(.zero, zon.hotbar.slotSize);
    for (zon.hotbar.slots, 0..) |offset, i| {
        if (slotRect.move(offset).contains(mouse)) return i;
    }
    return null;
}

fn hoveredInventory() ?Hover {
    const mouse = zhu.window.mouse.sub(zon.inventory.position);
    const inventoryRect = zhu.Rect.init(.zero, zon.inventory.size);
    if (!inventoryRect.contains(mouse)) return null;

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
    zhu.camera.push(.windowAt(zon.hotbar.position));
    defer zhu.camera.pop();

    const atlas = zhu.assets.getImage(zon.hotbar.imageId).?;
    const panelImage = zhu.NineImage.from(atlas, zon.hotbar.panel);
    const slotImage = zhu.NineImage.from(atlas, zon.hotbar.slot);
    const selectedImage = zhu.NineImage.from(atlas, zon.hotbar.selected);

    // 绘制面板
    const panelRect = zhu.Rect.init(.zero, zon.hotbar.size);
    zhu.batch.drawNine(panelImage, panelRect);

    for (hotbar, zon.hotbar.slots, 0..) |slotIndex, offset, i| {
        const rect = zhu.Rect.init(offset, zon.hotbar.slotSize);
        // 绘制槽位
        zhu.batch.drawNine(slotImage, rect);

        if (i == activeHotbar) {
            zhu.batch.drawNine(selectedImage, rect);
        }

        const slot = slots[slotIndex orelse continue];
        if (slot.count == 0) continue;

        const iconSize = factory.itemConfig(slot.type).icon.size;
        drawItemIcon(slot.type, rect.center(), iconSize);
        if (slot.count > 1) drawItemCount(slot.count, rect);
    }
}

fn drawInventoryPanel() void {
    zhu.camera.push(.windowAt(zon.inventory.position));
    defer zhu.camera.pop();

    const atlas = zhu.assets.getImage(zon.inventory.imageId).?;
    const panelImage = zhu.NineImage.from(atlas, zon.inventory.panel);
    const slotImage = zhu.NineImage.from(atlas, zon.inventory.slot);

    const panelRect = zhu.Rect.init(.zero, zon.inventory.size);
    zhu.batch.drawNine(panelImage, panelRect);

    const first = activePage * pageSize;
    for (zon.inventory.slots, 0..) |offset, i| {
        const slotRect = zhu.Rect.init(offset, zon.inventory.slotSize);
        zhu.batch.drawNine(slotImage, slotRect);

        const slot = slots[first + i];
        if (slot.count == 0) continue;

        const iconSize = factory.itemConfig(slot.type).icon.size;
        drawItemIcon(slot.type, slotRect.center(), iconSize);
        if (slot.count > 1) drawItemCount(slot.count, slotRect);
    }

    drawPageButton(slotImage, zon.inventory.prev, "<");
    drawPageButton(slotImage, zon.inventory.next, ">");

    const args = .{ activePage + 1, zon.inventory.pageCount };
    zhu.text.drawFmt("{d}/{d}", args, zon.inventory.pageText, .{
        .anchor = .center,
    });
}

fn drawPageButton(image: zhu.NineImage, rect: zhu.Rect, label: []const u8) void {
    zhu.batch.drawNine(image, rect);
    zhu.text.draw(label, rect.center(), .{ .anchor = .center });
}

fn drawItemIcon(itemType: ItemEnum, position: zhu.Vector2, size: zhu.Vector2) void {
    const image = factory.resolveImage(factory.itemConfig(itemType).icon);
    zhu.batch.drawImage(image, position, .{ .size = size, .anchor = .center });
}

fn drawItemCount(count: u32, rect: zhu.Rect) void {
    const pos = rect.max().sub(.square(1));
    zhu.text.drawFmt("{d}", .{count}, pos, .{ .anchor = .one });
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
