const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const context = @import("context.zig");
const factory = @import("factory.zig");

const ItemEnum = component.item.ItemEnum;
const ImageId = zhu.graphics.ImageId;
const NineSource = zhu.NineImage.Source;

const Config = struct { bar: bar.Zon, bag: bag.Zon };
const config: Config = @import("zon/inventory.zon");

pub const Stack = struct { type: ItemEnum = .hoe, count: u32 = 0 };
pub const Item = Stack;

const Hover = union(enum) { body, slot: usize, prev, next, close };

pub const bag = struct {
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
    const slotCount = pageSize * zon.pageCount;

    pub var slots: [slotCount]Stack = @splat(.{});
    pub var position: zhu.Vector2 = zon.position;
    pub var closed: bool = true;
    pub var activePage: usize = 0;
    var click: zhu.widget.ClickT(Hover) = .empty;
    var drag: ?zhu.Vector2 = null;

    fn reset() void {
        slots = @splat(.{});
        position = zon.position;
        closed = true;
        activePage = 0;
        click = .empty;
        drag = null;
    }

    pub fn add(itemType: ItemEnum, count: u32) u32 {
        const item = factory.itemConfig(itemType);

        var remaining: u32 = count;
        for (&slots) |*slot| { // 先尝试叠加到已有的同类型物品上。
            if (slot.count == 0 or slot.type != itemType) continue;

            const space = item.limit - slot.count;
            if (space == 0) continue;
            const minCount = @min(space, remaining);
            slot.count += minCount;
            remaining -= minCount;
            if (remaining == 0) break;
        }

        for (&slots) |*slot| { // 再尝试放到空槽位。
            if (slot.count > 0 or remaining == 0) continue;

            const minCount = @min(item.limit, remaining);
            slot.* = .{ .type = itemType, .count = minCount };
            remaining -= minCount;
        }

        if (remaining < count) autoBind(itemType);
        return remaining;
    }

    pub fn move(fromIndex: usize, toIndex: usize) void {
        if (fromIndex == toIndex) return;

        const from, const to = .{ &slots[fromIndex], &slots[toIndex] };
        if (from.count == 0) return;

        // 空槽或不同物品：交换两格，快捷栏引用同步交换。
        if (to.count == 0 or from.type != to.type) {
            std.mem.swap(Stack, from, to);
            bar.swapRefs(fromIndex, toIndex);
            return;
        }

        // 同物品：尽量合并到目标格。
        const limit = factory.itemConfig(from.type).limit;
        const moved = @min(limit - to.count, from.count);
        if (moved == 0) return;

        to.count += moved;
        from.count -= moved;
        if (from.count > 0) return;

        from.* = .{};
        // 合并后源槽清空，快捷栏引用转到目标槽。
        bar.replaceRefs(fromIndex, toIndex);
    }

    fn autoBind(itemType: ItemEnum) void {
        if (bar.hasItem(itemType)) return;

        const bagIndex = firstSlot(itemType) orelse return;
        const barIndex = bar.firstEmpty() orelse return;
        bar.bind(barIndex, bagIndex);
    }

    fn firstSlot(itemType: ItemEnum) ?usize {
        for (slots, 0..) |slot, index| {
            if (slot.count > 0 and slot.type == itemType) return index;
        }
        return null;
    }

    fn update() void {
        if (context.input.pressed(.inventory)) {
            closed = !closed;
            if (closed) click, drag = .{ .empty, null };
        }
        if (closed) return;
        if (updatePanelDrag()) return;

        const clicked = click.update(hovered()) orelse return;
        activePage = switch (clicked) {
            .prev => activePage -| 1,
            .next => @min(activePage + 1, zon.pageCount - 1),
            .close => {
                closed, click, drag = .{ true, .empty, null };
                return;
            },
            .body, .slot => return,
        };
    }

    fn updatePanelDrag() bool {
        if (drag) |offset| {
            if (zhu.mouse.released(.LEFT)) drag = null else {
                position = zhu.window.mouse.sub(offset);
            }
            return true;
        }

        if (!zhu.mouse.pressed(.LEFT)) return false;
        if (!std.meta.eql(hovered(), .body)) return false;

        drag = zhu.window.mouse.sub(position);
        click = .empty;
        return true;
    }

    fn hovered() ?Hover {
        const mouse = zhu.window.mouse.sub(position);
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

    fn hoveredSlotIndex() ?usize {
        if (closed) return null;

        return switch (hovered() orelse return null) {
            .slot => |index| activePage * pageSize + index,
            .body, .prev, .next, .close => null,
        };
    }

    fn draw() void {
        if (closed) return;
        zhu.camera.push(.windowAt(position));
        defer zhu.camera.pop();

        const atlas = zhu.assets.getImage(zon.imageId).?;
        const buttonImage = zhu.assets.getImage(zon.buttonImageId).?;
        const panelImage = zhu.NineImage.from(atlas, zon.panel);
        const slotImage = zhu.NineImage.from(atlas, zon.slot);

        const panelRect = zhu.Rect.init(.zero, zon.size);
        zhu.batch.drawNine(panelImage, panelRect);

        const first = activePage * pageSize;
        for (zon.slots) |offset| {
            const slotRect = zhu.Rect.init(offset, zon.slotSize);
            zhu.batch.drawNine(slotImage, slotRect);
        }

        for (zon.slots, 0..) |offset, i| {
            const slotRect = zhu.Rect.init(offset, zon.slotSize);
            const slot = slots[first + i];
            if (slot.count == 0) continue;
            if (itemDrag.hideBag(first + i)) continue;

            drawItemIcon(slot.type, slotRect.center());
        }

        for (zon.slots, 0..) |offset, i| {
            const slotRect = zhu.Rect.init(offset, zon.slotSize);
            const slot = slots[first + i];
            if (slot.count <= 1) continue;
            if (itemDrag.hideBag(first + i)) continue;

            drawItemCount(slot.count, slotRect);
        }

        drawButton(buttonImage, zon.prev, .prev);
        drawButton(buttonImage, zon.next, .next);
        drawButton(buttonImage, zon.close, .close);

        const args = .{ activePage + 1, zon.pageCount };
        zhu.text.drawFmt("{d}/{d}", args, zon.pageText, .{
            .anchor = .center,
            .color = .black,
        });
    }

    fn drawButton(image: zhu.Image, button: Zon.Button, hover: Hover) void {
        var pressed = false;
        if (click.pressed) |p| pressed = std.meta.eql(p, hover);

        const source = if (pressed) button.pressed else button.normal;
        zhu.batch.drawImage(image.sub(source), button.rect.min, .{
            .size = button.rect.size,
        });
    }
};

pub const bar = struct {
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

    pub var refs: [zon.slots.len]?usize = @splat(null);
    pub var active: usize = 0;
    pub var visible: bool = true;
    var click: zhu.widget.Click = .empty;

    fn reset() void {
        refs = @splat(null);
        active = 0;
        visible = true;
        click = .empty;
    }

    fn item() ?*Stack {
        const index = refs[active] orelse return null;
        if (bag.slots[index].count == 0) return null;
        return &bag.slots[index];
    }

    fn bind(barIndex: usize, bagIndex: usize) void {
        clearItemRefs(bag.slots[bagIndex].type);
        refs[barIndex] = bagIndex;
    }

    fn moveBinding(fromIndex: usize, toIndex: usize) void {
        if (fromIndex == toIndex) return;

        const from = refs[fromIndex] orelse return;
        refs[fromIndex] = refs[toIndex];
        refs[toIndex] = from;
    }

    fn clearItemRefs(itemType: ItemEnum) void {
        for (&refs) |*slotIndex| {
            const index = slotIndex.* orelse continue;
            if (bag.slots[index].type == itemType) slotIndex.* = null;
        }
    }

    fn replaceRefs(fromIndex: usize, toIndex: usize) void {
        for (&refs) |*slotIndex| {
            if (slotIndex.* == fromIndex) slotIndex.* = toIndex;
        }
    }

    fn swapRefs(a: usize, b: usize) void {
        for (&refs) |*slotIndex| {
            const index = slotIndex.* orelse continue;
            if (index == a) slotIndex.* = b;
            if (index == b) slotIndex.* = a;
        }
    }

    fn hasItem(itemType: ItemEnum) bool {
        for (refs) |slotIndex| {
            const index = slotIndex orelse continue;
            const slot = bag.slots[index];
            if (slot.count > 0 and slot.type == itemType) return true;
        }
        return false;
    }

    fn firstEmpty() ?usize {
        for (refs, 0..) |slotIndex, index| {
            const bagIndex = slotIndex orelse return index;
            if (bag.slots[bagIndex].count == 0) return index;
        }
        return null;
    }

    fn update() void {
        if (context.input.pressed(.hotbar)) {
            visible = !visible;
            click = .empty;
        }

        if (context.input.hotbarPressed()) |index| active = index;

        if (!visible) return;

        if (click.update(hoveredSlot())) |index| {
            active = index;
            zhu.audio.playSound("assets/audio/UI_button08.ogg");
        }
    }

    fn hoveredSlot() ?usize {
        if (!visible) return null;

        const mouse = zhu.window.mouse.sub(zon.position);
        const slotRect = zhu.Rect.init(.zero, zon.slotSize);
        for (zon.slots, 0..) |offset, i| {
            if (slotRect.move(offset).contains(mouse)) return i;
        }
        return null;
    }

    fn draw() void {
        if (!visible) return;
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

            if (i == active) {
                zhu.batch.drawNine(selectedImage, rect);
            }
        }

        for (refs, zon.slots, 0..) |slotIndex, offset, i| {
            const rect = zhu.Rect.init(offset, zon.slotSize);
            const slot = bag.slots[slotIndex orelse continue];
            if (slot.count == 0 or itemDrag.hideBar(i)) continue;

            drawItemIcon(slot.type, rect.center());
        }

        for (refs, zon.slots, 0..) |slotIndex, offset, i| {
            const rect = zhu.Rect.init(offset, zon.slotSize);
            const slot = bag.slots[slotIndex orelse continue];
            if (slot.count <= 1) continue;
            if (itemDrag.hideBar(i)) continue;

            drawItemCount(slot.count, rect);
        }
    }
};

const itemDrag = struct {
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

    var state: ?State = null;

    fn update() void {
        if (zhu.mouse.pressed(.LEFT)) start();

        if (state) |*current| {
            const offset = zhu.window.mouse.sub(current.start);
            if (offset.length2() >= threshold2) current.moved = true;

            if (zhu.mouse.released(.LEFT)) finish();
        }
    }

    fn start() void {
        state = null;

        if (bag.hoveredSlotIndex()) |index| {
            const slot = bag.slots[index];
            if (slot.count == 0) return;

            state = .{
                .source = .{ .bag = index },
                .bagIndex = index,
                .item = slot,
                .start = zhu.window.mouse,
            };
            return;
        }

        const barIndex = bar.hoveredSlot() orelse return;
        const bagIndex = bar.refs[barIndex] orelse return;
        const slot = bag.slots[bagIndex];
        if (slot.count == 0) return;

        state = .{
            .source = .{ .bar = barIndex },
            .bagIndex = bagIndex,
            .item = slot,
            .start = zhu.window.mouse,
        };
    }

    fn finish() void {
        const current = state orelse return;
        state = null;

        if (!current.moved) return;

        // 松开鼠标后才改真实数据，避免拖拽中破坏库存不变量。
        switch (current.source) {
            .bag => |from| finishBag(from),
            .bar => |from| finishBar(from, current.bagIndex),
        }
    }

    fn finishBag(fromIndex: usize) void {
        switch (target() orelse return) {
            .bag => |toIndex| move(fromIndex, toIndex),
            .bar => |barIndex| bar.bind(barIndex, fromIndex),
        }
    }

    fn finishBar(fromBar: usize, fromBag: usize) void {
        switch (target() orelse {
            bar.refs[fromBar] = null;
            return;
        }) {
            .bag => |toIndex| move(fromBag, toIndex),
            .bar => |toBar| bar.moveBinding(fromBar, toBar),
        }
    }

    fn target() ?Target {
        if (bag.hoveredSlotIndex()) |index| {
            return .{ .bag = index };
        }
        if (bar.hoveredSlot()) |index| return .{ .bar = index };
        return null;
    }

    fn hideBag(index: usize) bool {
        const current = state orelse return false;
        if (!current.moved) return false;
        return switch (current.source) {
            .bag => |source| source == index,
            .bar => false,
        };
    }

    fn hideBar(index: usize) bool {
        const current = state orelse return false;
        if (!current.moved) return false;
        return switch (current.source) {
            .bar => |source| source == index,
            .bag => false,
        };
    }

    fn draw() void {
        const current = state orelse return;
        if (!current.moved) return;

        zhu.camera.push(.window);
        defer zhu.camera.pop();

        drawItemIcon(current.item.type, zhu.window.mouse);

        if (current.item.count <= 1) return;

        const rect = zhu.Rect.init(
            zhu.window.mouse.sub(bag.zon.slotSize.scale(0.5)),
            bag.zon.slotSize,
        );
        drawItemCount(current.item.count, rect);
    }
};

pub fn reset() void {
    bag.reset();
    bar.reset();
    itemDrag.state = null;
}

pub fn add(itemType: ItemEnum, count: u32) u32 {
    return bag.add(itemType, count);
}

pub fn activeItem() ?*Stack {
    return bar.item();
}

pub fn move(fromIndex: usize, toIndex: usize) void {
    bag.move(fromIndex, toIndex);
}

pub fn update() void {
    const panelDragging = bag.drag != null;

    bag.update();
    if (panelDragging or bag.drag != null) {
        context.input.mouseCaptured = true;
        return;
    }

    bar.update();
    itemDrag.update();

    if (itemDrag.state != null or bag.drag != null or
        bag.click.captured or bar.click.captured)
    {
        context.input.mouseCaptured = true;
    }
}

pub fn draw() void {
    bag.draw();
    bar.draw();
    itemDrag.draw();
    drawTooltip();
}

fn tooltipItem() ?ItemEnum {
    if (itemDrag.state != null or bag.drag != null) return null;

    if (bag.hoveredSlotIndex()) |index| {
        const slot = bag.slots[index];
        if (slot.count > 0) return slot.type;
    }

    const barIndex = bar.hoveredSlot() orelse return null;
    const bagIndex = bar.refs[barIndex] orelse return null;
    const slot = bag.slots[bagIndex];
    return if (slot.count > 0) slot.type else null;
}

fn drawTooltip() void {
    const itemType = tooltipItem() orelse return;
    const item = factory.itemConfig(itemType);
    const tooltip = bag.zon.tooltip;

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
    const position = zhu.widget.popupPosition(.{
        .anchor = zhu.window.mouse,
        .size = size,
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
    reset();

    _ = add(.strawberry, 7);
    _ = add(.strawberry, 3);

    try std.testing.expectEqual(.strawberry, bag.slots[0].type);
    try std.testing.expectEqual(10, bag.slots[0].count);
    try std.testing.expectEqual(0, bar.refs[0].?);
}

test "添加物品超过堆叠上限会填入下一个库存槽" {
    reset();

    _ = add(.strawberry, 100);

    try std.testing.expectEqual(99, bag.slots[0].count);
    try std.testing.expectEqual(1, bag.slots[1].count);
    try std.testing.expectEqual(0, bar.refs[0].?);
    try std.testing.expectEqual(null, bar.refs[1]);
}

test "当前物品通过快捷栏引用读取库存槽" {
    reset();

    bar.active = 1;
    bag.slots[5] = .{ .type = .potatoSeed, .count = 2 };
    bar.refs[1] = 5;

    try std.testing.expectEqual(.potatoSeed, activeItem().?.type);
    try std.testing.expectEqual(2, activeItem().?.count);

    bag.slots[5].count = 0;
    try std.testing.expectEqual(null, activeItem());
}

test "同一种物品只能绑定到一个快捷栏槽位" {
    reset();

    // Zig 版快捷栏按物品类型唯一绑定，避免同类物品占用多个快捷键。
    bag.slots[0] = .{ .type = .strawberrySeed, .count = 2 };
    bag.slots[2] = .{ .type = .strawberrySeed, .count = 4 };

    bar.bind(0, 0);
    bar.bind(3, 2);

    try std.testing.expectEqual(null, bar.refs[0]);
    try std.testing.expectEqual(2, bar.refs[3].?);
}

test "快捷栏拖到空快捷栏会移动绑定" {
    reset();

    bag.slots[0] = .{ .type = .strawberry, .count = 5 };
    bar.bind(0, 0);

    bar.moveBinding(0, 4);

    try std.testing.expectEqual(null, bar.refs[0]);
    try std.testing.expectEqual(0, bar.refs[4].?);
}

test "快捷栏拖到已有快捷栏会交换绑定" {
    reset();

    bag.slots[0] = .{ .type = .strawberry, .count = 5 };
    bag.slots[1] = .{ .type = .potato, .count = 3 };
    bar.bind(0, 0);
    bar.bind(4, 1);

    bar.moveBinding(0, 4);

    try std.testing.expectEqual(1, bar.refs[0].?);
    try std.testing.expectEqual(0, bar.refs[4].?);
}

test "移动到空槽时快捷栏引用跟随物品" {
    reset();

    bag.slots[0] = .{ .type = .strawberry, .count = 5 };
    bar.bind(2, 0);

    move(0, 5);

    try std.testing.expectEqual(0, bag.slots[0].count);
    try std.testing.expectEqual(.strawberry, bag.slots[5].type);
    try std.testing.expectEqual(5, bag.slots[5].count);
    try std.testing.expectEqual(5, bar.refs[2].?);
}

test "交换不同物品时快捷栏引用跟随物品" {
    reset();

    bag.slots[0] = .{ .type = .strawberry, .count = 5 };
    bag.slots[1] = .{ .type = .potato, .count = 3 };
    bar.bind(0, 0);
    bar.bind(1, 1);

    move(0, 1);

    try std.testing.expectEqual(.potato, bag.slots[0].type);
    try std.testing.expectEqual(.strawberry, bag.slots[1].type);
    try std.testing.expectEqual(1, bar.refs[0].?);
    try std.testing.expectEqual(0, bar.refs[1].?);
}

test "合并后源槽清空且目标无快捷栏时转移引用" {
    reset();

    bag.slots[0] = .{ .type = .strawberry, .count = 5 };
    bag.slots[1] = .{ .type = .strawberry, .count = 4 };
    bar.bind(0, 0);

    move(0, 1);

    try std.testing.expectEqual(0, bag.slots[0].count);
    try std.testing.expectEqual(9, bag.slots[1].count);
    try std.testing.expectEqual(1, bar.refs[0].?);
}

test "合并到已有快捷栏目标时保留目标引用" {
    reset();

    bag.slots[0] = .{ .type = .strawberry, .count = 5 };
    bag.slots[1] = .{ .type = .strawberry, .count = 4 };
    bar.bind(1, 1);

    move(0, 1);

    try std.testing.expectEqual(0, bag.slots[0].count);
    try std.testing.expectEqual(9, bag.slots[1].count);
    try std.testing.expectEqual(null, bar.refs[0]);
    try std.testing.expectEqual(1, bar.refs[1].?);
}
