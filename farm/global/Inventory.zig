const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const factory = @import("../factory.zig");
const input = @import("../input.zig");
const state = @import("../state.zig");

const ItemEnum = component.item.ItemEnum;
const ImageId = zhu.graphics.ImageId;
const NineSource = zhu.NineImage.Source;

const Config = struct { bar: Bar.Zon, bag: Bag.Zon };
const config: Config = @import("../zon/inventory.zon");
const len = config.bag.slots.len * config.bag.pageCount;

const Store = zhu.widget.StackStore(ItemEnum, len, stackLimit);
const Notice = state.Notice;

pub const Stack = Store.Stack;
pub const Item = Stack;
pub const UseResult = union(enum) { none, full, item: Stack };
pub const Save = struct {
    activeHotbar: usize = 0,
    activePage: usize = 0,
    slots: []const Stack = &.{},
    hotbar: [Bar.zon.slots.len]?usize = @splat(null),
};

const Hover = union(enum) { body, slot: usize, prev, next, close };

fn stackLimit(itemType: ItemEnum) u32 {
    // 叠加上限由物品配置决定，库存逻辑只执行规则。
    return factory.itemConfig(itemType).limit;
}

const Bag = struct {
    const Zon = struct {
        const Button = struct {
            rect: zhu.Rect,
            normal: zhu.Rect,
            pressed: zhu.Rect,
        };

        const Tooltip = struct {
            imageId: ImageId,
            minSize: zhu.Vector2,
            offset: zhu.Vector2,
            padding: zhu.Vector2,
            spacing: f32,
            text: zhu.text.Option,
            panel: NineSource,
        };

        imageId: ImageId,
        buttonImageId: ImageId,
        position: zhu.Vector2,
        size: zhu.Vector2,
        pageCount: usize,
        slotSize: zhu.Vector2,
        slots: [20]zhu.Vector2,
        prev: Button,
        next: Button,
        pageText: zhu.Vector2,
        close: Button,
        panel: NineSource,
        slot: NineSource,
        tooltip: Tooltip,
    };

    const zon = config.bag;
    const pageSize = zon.slots.len;

    position: zhu.Vector2 = zon.position,
    closed: bool = true,
    activePage: usize = 0,
    click: zhu.widget.ClickT(Hover) = .empty,
    drag: ?zhu.Vector2 = null,

    fn reset(self: *Bag) void {
        self.position = zon.position;
        self.closed = true;
        self.activePage = 0;
        self.click = .empty;
        self.drag = null;
    }

    fn add(self: *Bag, inv: *Inventory, itemType: ItemEnum, count: u32) u32 {
        const remaining = inv.store.add(itemType, count);
        if (remaining < count) self.autoBind(inv, itemType);
        return remaining;
    }

    fn useByIndex(self: *Bag, inv: *Inventory, index: usize) UseResult {
        std.debug.assert(index < inv.store.stacks.len);

        const slot = inv.store.getPtr(index) orelse return .none;
        const cfg = factory.itemConfig(slot.item);
        const effect = cfg.product orelse return .none;

        if (slot.count == 1) {
            slot.* = .{ .item = effect.item, .count = effect.count };
            self.autoBind(inv, effect.item);
            return .{ .item = slot.* };
        }

        if (!inv.store.useAt(index, addArgs(effect.item, effect.count))) {
            return .full;
        }

        self.autoBind(inv, effect.item);
        return .{ .item = .{ .item = effect.item, .count = effect.count } };
    }

    fn addArgs(itemType: ItemEnum, count: u32) Store.Count {
        return .{
            .item = itemType,
            .count = count,
        };
    }

    fn move(self: *Bag, inv: *Inventory, fromIndex: usize, toIndex: usize) void {
        _ = self;
        if (fromIndex == toIndex) return;

        const moved = inv.store.move(fromIndex, toIndex) orelse return;

        switch (moved) {
            .swap => inv.bar.swapRefs(fromIndex, toIndex),
            .merge => {},
            .clear => inv.bar.replaceRefs(fromIndex, toIndex),
        }
    }

    fn autoBind(self: *Bag, inv: *Inventory, itemType: ItemEnum) void {
        _ = self;
        if (inv.bar.hasItem(inv, itemType)) return;

        const bagIndex = inv.store.first(itemType) orelse return;
        const barIndex = inv.bar.firstEmpty(inv) orelse return;
        inv.bar.bind(inv, barIndex, bagIndex);
    }

    fn update(self: *Bag) void {
        if (input.pressed(.inventory)) {
            self.closed = !self.closed;
            if (self.closed) self.click, self.drag = .{ .empty, null };
        }
        if (self.closed) return;
        if (self.updatePanelDrag()) return;

        const clicked = self.click.update(self.hovered()) orelse return;
        self.activePage = switch (clicked) {
            .prev => self.activePage -| 1,
            .next => @min(self.activePage + 1, zon.pageCount - 1),
            .close => {
                self.closed, self.click, self.drag = .{ true, .empty, null };
                return;
            },
            .body, .slot => return,
        };
    }

    fn updatePanelDrag(self: *Bag) bool {
        if (self.drag) |offset| {
            if (zhu.mouse.released(.LEFT)) self.drag = null else {
                self.position = zhu.window.mouse.sub(offset);
            }
            return true;
        }

        if (!zhu.mouse.pressed(.LEFT)) return false;
        if (!std.meta.eql(self.hovered(), .body)) return false;

        self.drag = zhu.window.mouse.sub(self.position);
        self.click = .empty;
        return true;
    }

    fn hovered(self: *const Bag) ?Hover {
        const mouse = zhu.window.mouse.sub(self.position);
        if (zon.close.rect.contains(mouse)) return .close;

        const bagRect = zhu.Rect.init(.zero, zon.size);
        if (!bagRect.contains(mouse)) return null;

        const slotRect = zhu.Rect.init(.zero, zon.slotSize);
        for (zon.slots, 0..) |offset, i| {
            const rect = slotRect.move(offset);
            if (rect.contains(mouse)) return .{ .slot = i };
        }

        if (zon.prev.rect.contains(mouse)) return .prev;
        if (zon.next.rect.contains(mouse)) return .next;
        return .body;
    }

    fn hoveredSlotIndex(self: *const Bag) ?usize {
        if (self.closed) return null;

        return switch (self.hovered() orelse return null) {
            .slot => |index| self.activePage * pageSize + index,
            .body, .prev, .next, .close => null,
        };
    }

    fn draw(self: *Bag, inv: *Inventory) void {
        if (self.closed) return;
        zhu.camera.push(.windowAt(self.position));
        defer zhu.camera.pop();

        const atlas = zhu.assets.getImage(zon.imageId).?;
        const buttonImage = zhu.assets.getImage(zon.buttonImageId).?;
        const panelImage = zhu.NineImage.from(atlas, zon.panel);
        const slotImage = zhu.NineImage.from(atlas, zon.slot);

        const panelRect = zhu.Rect.init(.zero, zon.size);
        zhu.batch.drawNine(panelImage, panelRect);

        const first = self.activePage * pageSize;
        for (zon.slots) |offset| {
            const slotRect = zhu.Rect.init(offset, zon.slotSize);
            zhu.batch.drawNine(slotImage, slotRect);
        }

        for (zon.slots, 0..) |offset, i| {
            const slotRect = zhu.Rect.init(offset, zon.slotSize);
            const slot = inv.store.get(first + i) orelse continue;
            if (inv.itemDrag.hideBag(first + i)) continue;

            drawItemIcon(slot.item, slotRect.center());
        }

        for (zon.slots, 0..) |offset, i| {
            const slotRect = zhu.Rect.init(offset, zon.slotSize);
            const slot = inv.store.get(first + i) orelse continue;
            if (slot.count <= 1) continue;
            if (inv.itemDrag.hideBag(first + i)) continue;

            drawItemCount(slot.count, slotRect);
        }

        self.drawButton(buttonImage, zon.prev, .prev);
        self.drawButton(buttonImage, zon.next, .next);
        self.drawButton(buttonImage, zon.close, .close);

        const args = .{ self.activePage + 1, zon.pageCount };
        zhu.text.drawFmt("{d}/{d}", args, zon.pageText, .{
            .anchor = .center,
            .color = .black,
        });
    }

    fn drawButton(
        self: *Bag,
        image: zhu.Image,
        button: Zon.Button,
        hover: Hover,
    ) void {
        var pressed = false;
        if (self.click.pressed) |p| pressed = std.meta.eql(p, hover);

        const source = if (pressed) button.pressed else button.normal;
        zhu.batch.drawImage(image.sub(source), button.rect.min, .{
            .size = button.rect.size,
        });
    }
};

const Bar = struct {
    const Zon = struct {
        imageId: ImageId,
        position: zhu.Vector2,
        size: zhu.Vector2,
        slotSize: zhu.Vector2,
        slots: [10]zhu.Vector2,
        panel: NineSource,
        slot: NineSource,
        selected: NineSource,
    };

    const zon = config.bar;

    refs: [zon.slots.len]?usize = @splat(null),
    active: usize = 0,
    visible: bool = true,
    click: zhu.widget.Click = .empty,

    fn reset(self: *Bar) void {
        self.refs = @splat(null);
        self.active = 0;
        self.visible = true;
        self.click = .empty;
    }

    fn item(self: *Bar, inv: *Inventory) ?*Stack {
        return inv.store.getPtr(self.refs[self.active] orelse return null);
    }

    fn bind(self: *Bar, inv: *Inventory, barIndex: usize, bagIndex: usize) void {
        self.clearItemRefs(inv, inv.store.get(bagIndex).?.item);
        self.refs[barIndex] = bagIndex;
    }

    fn moveBinding(self: *Bar, fromIndex: usize, toIndex: usize) void {
        if (fromIndex == toIndex) return;

        const from = self.refs[fromIndex] orelse return;
        self.refs[fromIndex] = self.refs[toIndex];
        self.refs[toIndex] = from;
    }

    fn clearItemRefs(self: *Bar, inv: *Inventory, itemType: ItemEnum) void {
        for (&self.refs) |*slotIndex| {
            const index = slotIndex.* orelse continue;
            const slot = inv.store.getPtr(index) orelse continue;
            if (slot.item == itemType) slotIndex.* = null;
        }
    }

    fn replaceRefs(self: *Bar, fromIndex: usize, toIndex: usize) void {
        for (&self.refs) |*slotIndex| {
            if (slotIndex.* == fromIndex) slotIndex.* = toIndex;
        }
    }

    fn swapRefs(self: *Bar, a: usize, b: usize) void {
        for (&self.refs) |*slotIndex| {
            const index = slotIndex.* orelse continue;
            if (index == a) slotIndex.* = b;
            if (index == b) slotIndex.* = a;
        }
    }

    fn hasItem(self: *Bar, inv: *Inventory, itemType: ItemEnum) bool {
        for (self.refs) |slotIndex| {
            const index = slotIndex orelse continue;
            const slot = inv.store.getPtr(index) orelse continue;
            if (slot.item == itemType) return true;
        }
        return false;
    }

    fn firstEmpty(self: *Bar, inv: *Inventory) ?usize {
        for (self.refs, 0..) |slotIndex, index| {
            const bagIndex = slotIndex orelse return index;
            if (inv.store.get(bagIndex) == null) return index;
        }
        return null;
    }

    fn update(self: *Bar) void {
        if (input.pressed(.hotbar)) {
            self.visible = !self.visible;
            self.click = .empty;
        }

        if (input.hotbarPressed()) |index| self.active = index;

        if (!self.visible) return;

        if (self.click.update(self.hoveredSlot())) |index| {
            self.active = index;
            zhu.audio.playSound("audio/UI_button08.ogg");
        }
    }

    fn hoveredSlot(self: *const Bar) ?usize {
        if (!self.visible) return null;

        const mouse = zhu.window.mouse.sub(zon.position);
        const slotRect = zhu.Rect.init(.zero, zon.slotSize);
        for (zon.slots, 0..) |offset, i| {
            if (slotRect.move(offset).contains(mouse)) return i;
        }
        return null;
    }

    fn draw(self: *Bar, inv: *Inventory) void {
        if (!self.visible) return;
        zhu.camera.push(.windowAt(zon.position));
        defer zhu.camera.pop();

        const atlas = zhu.assets.getImage(zon.imageId).?;
        const panelImage = zhu.NineImage.from(atlas, zon.panel);
        const slotImage = zhu.NineImage.from(atlas, zon.slot);
        const selectedImage = zhu.NineImage.from(atlas, zon.selected);

        // 绘制面板
        const panelRect = zhu.Rect.init(.zero, zon.size);
        zhu.batch.drawNine(panelImage, panelRect);

        for (zon.slots, 0..) |offset, i| {
            const rect = zhu.Rect.init(offset, zon.slotSize);
            // 绘制槽位
            zhu.batch.drawNine(slotImage, rect);

            if (i == self.active) {
                zhu.batch.drawNine(selectedImage, rect);
            }
        }

        for (self.refs, zon.slots, 0..) |slotIndex, offset, i| {
            const rect = zhu.Rect.init(offset, zon.slotSize);
            const slot = inv.store.get(slotIndex orelse continue) orelse continue;
            if (inv.itemDrag.hideBar(i)) continue;

            drawItemIcon(slot.item, rect.center());
        }

        for (self.refs, zon.slots, 0..) |slotIndex, offset, i| {
            const rect = zhu.Rect.init(offset, zon.slotSize);
            const slot = inv.store.get(slotIndex orelse continue) orelse continue;
            if (slot.count <= 1) continue;
            if (inv.itemDrag.hideBar(i)) continue;

            drawItemCount(slot.count, rect);
        }
    }
};

const ItemDrag = struct {
    const Source = union(enum) { bag: usize, bar: usize };
    const Target = union(enum) { bag: usize, bar: usize };
    const State = struct {
        source: Source,
        bagIndex: usize,
        item: Stack,
        start: zhu.Vector2,
        moved: bool = false,
    };

    const threshold2: f32 = 9;

    dragState: ?State = null,

    fn reset(self: *ItemDrag) void {
        self.dragState = null;
    }

    fn update(self: *ItemDrag, inv: *Inventory) void {
        if (zhu.mouse.pressed(.LEFT)) self.start(inv);

        if (self.dragState) |*current| {
            const offset = zhu.window.mouse.sub(current.start);
            if (offset.length2() >= threshold2) current.moved = true;

            if (zhu.mouse.released(.LEFT)) self.finish(inv);
        }
    }

    fn start(self: *ItemDrag, inv: *Inventory) void {
        self.dragState = null;

        if (inv.bag.hoveredSlotIndex()) |index| {
            const slot = inv.store.getPtr(index) orelse return;

            self.dragState = .{
                .source = .{ .bag = index },
                .bagIndex = index,
                .item = slot.*,
                .start = zhu.window.mouse,
            };
            return;
        }

        const barIndex = inv.bar.hoveredSlot() orelse return;
        const bagIndex = inv.bar.refs[barIndex] orelse return;
        const slot = inv.store.getPtr(bagIndex) orelse return;

        self.dragState = .{
            .source = .{ .bar = barIndex },
            .bagIndex = bagIndex,
            .item = slot.*,
            .start = zhu.window.mouse,
        };
    }

    fn finish(self: *ItemDrag, inv: *Inventory) void {
        const current = self.dragState orelse return;
        self.dragState = null;

        if (!current.moved) return;

        // 松开鼠标后才改真实数据，避免拖拽中破坏库存不变量。
        switch (current.source) {
            .bag => |from| self.finishBag(inv, from),
            .bar => |from| self.finishBar(inv, from, current.bagIndex),
        }
    }

    fn finishBag(self: *ItemDrag, inv: *Inventory, fromIndex: usize) void {
        switch (self.target(inv) orelse return) {
            .bag => |toIndex| inv.bag.move(inv, fromIndex, toIndex),
            .bar => |barIndex| inv.bar.bind(inv, barIndex, fromIndex),
        }
    }

    fn finishBar(
        self: *ItemDrag,
        inv: *Inventory,
        fromBar: usize,
        fromBag: usize,
    ) void {
        switch (self.target(inv) orelse {
            inv.bar.refs[fromBar] = null;
            return;
        }) {
            .bag => |toIndex| inv.bag.move(inv, fromBag, toIndex),
            .bar => |toBar| inv.bar.moveBinding(fromBar, toBar),
        }
    }

    fn target(self: *ItemDrag, inv: *Inventory) ?Target {
        _ = self;
        if (inv.bag.hoveredSlotIndex()) |index| {
            return .{ .bag = index };
        }
        if (inv.bar.hoveredSlot()) |index| return .{ .bar = index };
        return null;
    }

    fn hideBag(self: *const ItemDrag, index: usize) bool {
        const current = self.dragState orelse return false;
        if (!current.moved) return false;
        return switch (current.source) {
            .bag => |source| source == index,
            .bar => false,
        };
    }

    fn hideBar(self: *const ItemDrag, index: usize) bool {
        const current = self.dragState orelse return false;
        if (!current.moved) return false;
        return switch (current.source) {
            .bar => |source| source == index,
            .bag => false,
        };
    }

    fn draw(self: *ItemDrag) void {
        const current = self.dragState orelse return;
        if (!current.moved) return;

        zhu.camera.push(.window);
        defer zhu.camera.pop();

        // 拖拽预览半透明，对齐 CPP UIDragPreview 的 0.6 alpha
        const icon = factory.itemConfig(current.item.item).icon;
        zhu.batch.drawImage(factory.resolveImage(icon), zhu.window.mouse, .{
            .size = icon.size,
            .anchor = .center,
            .color = .{ .a = 0.6 },
        });

        if (current.item.count <= 1) return;

        const rect = zhu.Rect.init(
            zhu.window.mouse.sub(Bag.zon.slotSize.scale(0.5)),
            Bag.zon.slotSize,
        );
        drawItemCount(current.item.count, rect);
    }
};

pub const Inventory = struct {
    store: Store = .{},
    bag: Bag = .{},
    bar: Bar = .{},
    itemDrag: ItemDrag = .{},

    pub fn reset(self: *Inventory) void {
        self.store.clear();
        self.bag.reset();
        self.bar.reset();
        self.itemDrag.reset();
        input.mouseCaptured = false;
    }

    pub fn capture(self: *Inventory) Save {
        return .{
            .activeHotbar = self.bar.active,
            .activePage = self.bag.activePage,
            .slots = self.store.stacks[0..],
            .hotbar = self.bar.refs,
        };
    }

    pub fn restore(self: *Inventory, data: Save) void {
        self.reset();
        for (data.slots, 0..) |slot, index| {
            if (index >= self.store.stacks.len) break;
            self.store.stacks[index] = slot;
        }
        self.bar.refs = data.hotbar;
        self.bar.active = data.activeHotbar;
        self.bag.activePage = data.activePage;
    }

    pub fn add(self: *Inventory, itemType: ItemEnum, count: u32) u32 {
        return self.bag.add(self, itemType, count);
    }

    pub fn activeItem(self: *Inventory) ?ItemEnum {
        return if (self.bar.item(self)) |stack| stack.item else null;
    }

    pub fn use(self: *Inventory, itemType: ItemEnum, count: u32) bool {
        std.debug.assert(count > 0);
        return self.store.subAll(itemType, count);
    }

    pub fn update(self: *Inventory, notice: *Notice) void {
        const panelDragging = self.bag.drag != null;

        self.bag.update();
        if (panelDragging or self.bag.drag != null) {
            input.mouseCaptured = true;
            return;
        }

        if (self.updateUseItem(notice)) {
            input.mouseCaptured = true;
            return;
        }

        self.bar.update();
        self.itemDrag.update(self);

        if (self.itemDrag.dragState != null or self.bag.drag != null or
            self.bag.click.captured or self.bar.click.captured)
        {
            input.mouseCaptured = true;
        }
    }

    fn updateUseItem(self: *Inventory, notice: *Notice) bool {
        if (self.itemDrag.dragState != null or self.bag.drag != null) {
            return false;
        }
        if (!input.mousePressed(.RIGHT)) return false;

        const index = self.hoveredBagIndex() orelse return false;
        switch (self.bag.useByIndex(self, index)) {
            .none => {},
            .full => notice.show("背包已满", .{}),
            .item => |value| notice.show("获得 {s} x{d}", .{
                factory.itemConfig(value.item).name,
                value.count,
            }),
        }
        return true;
    }

    fn hoveredBagIndex(self: *Inventory) ?usize {
        if (self.bag.hoveredSlotIndex()) |index| return index;

        const barIndex = self.bar.hoveredSlot() orelse return null;
        return self.bar.refs[barIndex];
    }

    pub fn draw(self: *Inventory) void {
        self.bag.draw(self);
        self.bar.draw(self);
        self.itemDrag.draw();
        self.drawTooltip();
    }

    fn tooltipItem(self: *Inventory) ?ItemEnum {
        if (self.itemDrag.dragState != null or self.bag.drag != null) {
            return null;
        }

        if (self.bag.hoveredSlotIndex()) |index| {
            const slot = self.store.getPtr(index) orelse return null;
            return slot.item;
        }

        const barIndex = self.bar.hoveredSlot() orelse return null;
        const bagIndex = self.bar.refs[barIndex] orelse return null;
        const slot = self.store.getPtr(bagIndex) orelse return null;
        return slot.item;
    }

    fn drawTooltip(self: *Inventory) void {
        const itemType = self.tooltipItem() orelse return;
        drawItemTooltip(itemType);
    }
};

fn drawItemTooltip(itemType: ItemEnum) void {
    const item = factory.itemConfig(itemType);
    const tooltip = Bag.zon.tooltip;

    const option = tooltip.text;
    const categoryColor = zhu.Color.gray(0.2, 1).toSrgb();
    const categoryOption = option.with(.color, categoryColor);
    const lines = [_]zhu.text.Line{
        .{ .text = item.name, .option = option },
        .{ .text = item.category, .option = categoryOption },
        .{ .text = item.description, .option = option },
    };

    const size = zhu.text.measureLines(&lines, tooltip.spacing)
        .add(tooltip.padding.scale(2)).max(tooltip.minSize);
    // 判方向用最大宽度，避免描述长短变化导致 tooltip 左右跳
    const maxWidth: f32 = 200;
    const position = zhu.widget.popupPosition(.{
        .anchor = zhu.window.mouse,
        .size = size,
        .maxSize = .{ .x = maxWidth, .y = size.y },
        .offset = tooltip.offset,
    });

    zhu.camera.push(.window);
    defer zhu.camera.pop();

    const image = zhu.assets.getImage(tooltip.imageId).?;
    const panel = zhu.NineImage.from(image, tooltip.panel);
    zhu.batch.drawNine(panel, .init(position, size));

    const pos = position.add(tooltip.padding);
    zhu.text.drawLines(&lines, pos, tooltip.spacing);
}

fn drawItemIcon(itemType: ItemEnum, position: zhu.Vector2) void {
    const icon = factory.itemConfig(itemType).icon;
    zhu.batch.drawImage(factory.resolveImage(icon), position, .{
        .size = icon.size,
        .anchor = .center,
    });
}

fn drawItemCount(count: u32, rect: zhu.Rect) void {
    const pos = rect.max().sub(.square(1));
    zhu.text.drawFmt("{d}", .{count}, pos, .{ .anchor = .one });
}

test "添加物品会合并并自动绑定快捷栏" {
    var inv: Inventory = .{};
    inv.reset();

    _ = inv.add(.strawberry, 7);
    _ = inv.add(.strawberry, 3);

    try std.testing.expectEqual(.strawberry, inv.activeItem().?);
    const index = inv.bar.refs[inv.bar.active].?;
    try std.testing.expectEqual(10, inv.store.stacks[index].count);
}

test "右键背包槽会使用物品" {
    var inv: Inventory = .{};
    zhu.input.reset();
    defer zhu.input.reset();
    var notice: Notice = .{};
    inv.reset();
    defer inv.reset();

    inv.bag.closed = false;
    inv.store.stacks[0] = .{ .item = .strawberry, .count = 2 };
    zhu.window.mouse = inv.bag.position.add(Bag.zon.slots[0]).add(.xy(1, 1));
    zhu.mouse.set(.RIGHT, true);

    inv.update(&notice);

    try std.testing.expect(input.mouseCaptured);
    try std.testing.expectEqual(.strawberry, inv.store.stacks[0].item);
    try std.testing.expectEqual(1, inv.store.stacks[0].count);
    try std.testing.expectEqual(.strawberrySeed, inv.store.stacks[1].item);
    try std.testing.expectEqual(3, inv.store.stacks[1].count);
}

test "右键快捷栏会使用绑定的背包槽" {
    var inv: Inventory = .{};
    zhu.input.reset();
    defer zhu.input.reset();
    var notice: Notice = .{};
    inv.reset();
    defer inv.reset();

    inv.store.stacks[5] = .{ .item = .potato, .count = 1 };
    inv.bar.refs[2] = 5;
    zhu.window.mouse = Bar.zon.position.add(Bar.zon.slots[2]).add(.xy(1, 1));
    zhu.mouse.set(.RIGHT, true);

    inv.update(&notice);

    try std.testing.expect(input.mouseCaptured);
    try std.testing.expectEqual(.potatoSeed, inv.store.stacks[5].item);
    try std.testing.expectEqual(3, inv.store.stacks[5].count);
}

test "右键使用物品成功后显示获得提示" {
    var inv: Inventory = .{};
    zhu.input.reset();
    defer zhu.input.reset();
    var notice: Notice = .{};
    inv.reset();
    defer inv.reset();

    inv.bag.closed = false;
    inv.store.stacks[0] = .{ .item = .potato, .count = 1 };
    zhu.window.mouse = inv.bag.position.add(Bag.zon.slots[0]).add(.xy(1, 1));
    zhu.mouse.set(.RIGHT, true);

    inv.update(&notice);

    const entry = notice.state();
    try std.testing.expectEqualStrings("获得 土豆种子 x3", entry.text);
    try std.testing.expect(entry.timer > 0);
}

test "右键使用物品空间不足时显示背包已满" {
    var inv: Inventory = .{};
    zhu.input.reset();
    defer zhu.input.reset();
    var notice: Notice = .{};
    inv.reset();
    defer inv.reset();

    inv.bag.closed = false;
    @memset(&inv.store.stacks, .{ .item = .potato, .count = 99 });
    inv.store.stacks[0] = .{ .item = .strawberry, .count = 2 };
    zhu.window.mouse = inv.bag.position.add(Bag.zon.slots[0]).add(.xy(1, 1));
    zhu.mouse.set(.RIGHT, true);

    inv.update(&notice);

    try std.testing.expectEqual(.strawberry, inv.store.stacks[0].item);
    try std.testing.expectEqual(2, inv.store.stacks[0].count);
    const entry = notice.state();
    try std.testing.expectEqualStrings("背包已满", entry.text);
    try std.testing.expect(entry.timer > 0);
}

test "新增工具会占用独立槽位" {
    var inv: Inventory = .{};
    inv.reset();

    try std.testing.expectEqual(0, inv.add(.hoe, 1));
    try std.testing.expectEqual(0, inv.add(.hoe, 1));

    try std.testing.expectEqual(.hoe, inv.store.stacks[0].item);
    try std.testing.expectEqual(1, inv.store.stacks[0].count);
    try std.testing.expectEqual(.hoe, inv.store.stacks[1].item);
    try std.testing.expectEqual(1, inv.store.stacks[1].count);
}

test "移动同类工具不会合并" {
    var inv: Inventory = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .hoe, .count = 1 };
    inv.store.stacks[1] = .{ .item = .hoe, .count = 1 };

    inv.bag.move(&inv, 0, 1);

    try std.testing.expectEqual(1, inv.store.stacks[0].count);
    try std.testing.expectEqual(1, inv.store.stacks[1].count);
}

test "当前物品通过快捷栏引用读取库存槽" {
    var inv: Inventory = .{};
    inv.reset();

    inv.bar.active = 1;
    inv.store.stacks[5] = .{ .item = .potatoSeed, .count = 2 };
    inv.bar.refs[1] = 5;

    try std.testing.expectEqual(.potatoSeed, inv.activeItem().?);
    try std.testing.expectEqual(2, inv.store.stacks[5].count);

    inv.store.stacks[5].count = 0;
    try std.testing.expectEqual(null, inv.activeItem());
}

test "同一种物品只能绑定到一个快捷栏槽位" {
    var inv: Inventory = .{};
    inv.reset();

    // Zig 版快捷栏按物品类型唯一绑定，避免同类物品占用多个快捷键。
    inv.store.stacks[0] = .{ .item = .strawberrySeed, .count = 2 };
    inv.store.stacks[2] = .{ .item = .strawberrySeed, .count = 4 };

    inv.bar.bind(&inv, 0, 0);
    inv.bar.bind(&inv, 3, 2);

    try std.testing.expectEqual(null, inv.bar.refs[0]);
    try std.testing.expectEqual(2, inv.bar.refs[3].?);
}

test "快捷栏拖到空快捷栏会移动绑定" {
    var inv: Inventory = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    inv.bar.bind(&inv, 0, 0);

    inv.bar.moveBinding(0, 4);

    try std.testing.expectEqual(null, inv.bar.refs[0]);
    try std.testing.expectEqual(0, inv.bar.refs[4].?);
}

test "快捷栏拖到已有快捷栏会交换绑定" {
    var inv: Inventory = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    inv.store.stacks[1] = .{ .item = .potato, .count = 3 };
    inv.bar.bind(&inv, 0, 0);
    inv.bar.bind(&inv, 4, 1);

    inv.bar.moveBinding(0, 4);

    try std.testing.expectEqual(1, inv.bar.refs[0].?);
    try std.testing.expectEqual(0, inv.bar.refs[4].?);
}

test "拖动物品到空槽后快捷栏继续指向该物品" {
    var inv: Inventory = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    inv.bar.bind(&inv, 2, 0);
    inv.bar.active = 2;

    inv.bag.move(&inv, 0, 5);

    try std.testing.expectEqual(.strawberry, inv.activeItem().?);
    try std.testing.expectEqual(5, inv.store.stacks[5].count);
}

test "交换不同物品后快捷栏继续指向原物品" {
    var inv: Inventory = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    inv.store.stacks[1] = .{ .item = .potato, .count = 3 };
    inv.bar.bind(&inv, 0, 0);
    inv.bar.bind(&inv, 1, 1);

    inv.bag.move(&inv, 0, 1);

    inv.bar.active = 0;
    try std.testing.expectEqual(.strawberry, inv.activeItem().?);
    try std.testing.expectEqual(5, inv.store.stacks[inv.bar.refs[0].?].count);

    inv.bar.active = 1;
    try std.testing.expectEqual(.potato, inv.activeItem().?);
    try std.testing.expectEqual(3, inv.store.stacks[inv.bar.refs[1].?].count);
}

test "合并同类物品后快捷栏继续指向合并物品" {
    var inv: Inventory = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    inv.store.stacks[1] = .{ .item = .strawberry, .count = 4 };
    inv.bar.bind(&inv, 0, 0);
    inv.bar.active = 0;

    inv.bag.move(&inv, 0, 1);

    try std.testing.expectEqual(.strawberry, inv.activeItem().?);
    try std.testing.expectEqual(9, inv.store.stacks[inv.bar.refs[0].?].count);
}

test "使用作物会消耗一个并产出种子" {
    var inv: Inventory = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .strawberry, .count = 2 };

    const result = inv.bag.useByIndex(&inv, 0);

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
    var inv: Inventory = .{};
    inv.reset();

    inv.store.stacks[0] = .{ .item = .potato, .count = 1 };
    inv.bar.refs[0] = 0;

    const result = inv.bag.useByIndex(&inv, 0);

    try std.testing.expectEqual(.potatoSeed, inv.store.stacks[0].item);
    try std.testing.expectEqual(3, inv.store.stacks[0].count);
    try std.testing.expectEqual(0, inv.bar.refs[0].?);
    try std.testing.expectEqual(.potatoSeed, inv.activeItem().?);

    const item = switch (result) {
        .item => |value| value,
        .none, .full => return error.TestExpectedEqual,
    };
    try std.testing.expectEqual(.potatoSeed, item.item);
    try std.testing.expectEqual(3, item.count);
}

test "use 会在数量足够时扣除指定物品" {
    var inv: Inventory = .{};
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
    var inv: Inventory = .{};
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
    var inv: Inventory = .{};
    inv.reset();

    inv.store.stacks[5] = .{ .item = .potato, .count = 1 };

    const result = inv.bag.useByIndex(&inv, 5);

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
    var inv: Inventory = .{};
    inv.reset();

    @memset(&inv.store.stacks, .{ .item = .potato, .count = 99 });
    inv.store.stacks[0] = .{ .item = .strawberry, .count = 2 };

    const result = inv.bag.useByIndex(&inv, 0);

    try std.testing.expectEqual(UseResult.full, result);
    try std.testing.expectEqual(.strawberry, inv.store.stacks[0].item);
    try std.testing.expectEqual(2, inv.store.stacks[0].count);
    try std.testing.expectEqual(.potato, inv.store.stacks[1].item);
    try std.testing.expectEqual(99, inv.store.stacks[1].count);
}
