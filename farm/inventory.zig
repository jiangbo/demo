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

const Store = zhu.widget.StackStore(ItemEnum, stackLimit);

pub const Stack = Store.Stack;
pub const Item = Stack;
pub const UseResult = union(enum) { none, full, item: Stack };

const Hover = union(enum) { body, slot: usize, prev, next, close };

fn stackLimit(itemType: ItemEnum) u32 {
    // 叠加上限由物品配置决定，库存逻辑只执行规则。
    return factory.itemConfig(itemType).limit;
}

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

    var slots: [slotCount]Stack = @splat(.{ .item = .hoe });
    pub var position: zhu.Vector2 = zon.position;
    pub var closed: bool = true;
    pub var activePage: usize = 0;
    var click: zhu.widget.ClickT(Hover) = .empty;
    var drag: ?zhu.Vector2 = null;

    fn reset() void {
        store.clear();
        position = zon.position;
        closed = true;
        activePage = 0;
        click = .empty;
        drag = null;
    }

    pub fn add(itemType: ItemEnum, count: u32) u32 {
        const remaining = store.add(itemType, count);
        if (remaining < count) autoBind(itemType);
        return remaining;
    }

    fn useByIndex(index: usize) UseResult {
        std.debug.assert(index < slots.len);

        const slot = store.getPtr(index) orelse return .none;

        const effect = factory.itemConfig(slot.item).use orelse return .none;

        if (slot.count == 1) {
            slot.* = .{ .item = effect.item, .count = effect.count };
            autoBind(effect.item);
            return .{ .item = slot.* };
        }

        if (!store.takeAdd(index, addArgs(effect.item, effect.count))) {
            return .full;
        }

        autoBind(effect.item);
        return .{ .item = .{ .item = effect.item, .count = effect.count } };
    }

    fn addArgs(itemType: ItemEnum, count: u32) Store.Add {
        return .{
            .item = itemType,
            .count = count,
        };
    }

    pub fn move(fromIndex: usize, toIndex: usize) void {
        if (fromIndex == toIndex) return;

        const moved = store.move(fromIndex, toIndex) orelse return;

        switch (moved) {
            .swap => bar.swapRefs(fromIndex, toIndex),
            .merge => {},
            .clear => bar.replaceRefs(fromIndex, toIndex),
        }
    }

    fn autoBind(itemType: ItemEnum) void {
        if (bar.hasItem(itemType)) return;

        const bagIndex = store.first(itemType) orelse return;
        const barIndex = bar.firstEmpty() orelse return;
        bar.bind(barIndex, bagIndex);
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
            const slot = store.get(first + i) orelse continue;
            if (itemDrag.hideBag(first + i)) continue;

            drawItemIcon(slot.item, slotRect.center());
        }

        for (zon.slots, 0..) |offset, i| {
            const slotRect = zhu.Rect.init(offset, zon.slotSize);
            const slot = store.get(first + i) orelse continue;
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

pub var store = Store{ .stacks = bag.slots[0..] };

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
        return store.getPtr(refs[active] orelse return null);
    }

    fn bind(barIndex: usize, bagIndex: usize) void {
        clearItemRefs(store.get(bagIndex).?.item);
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
            const slot = store.getPtr(index) orelse continue;
            if (slot.item == itemType) slotIndex.* = null;
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
            const slot = store.getPtr(index) orelse continue;
            if (slot.item == itemType) return true;
        }
        return false;
    }

    fn firstEmpty() ?usize {
        for (refs, 0..) |slotIndex, index| {
            const bagIndex = slotIndex orelse return index;
            if (store.get(bagIndex) == null) return index;
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
            const slot = store.get(slotIndex orelse continue) orelse continue;
            if (itemDrag.hideBar(i)) continue;

            drawItemIcon(slot.item, rect.center());
        }

        for (refs, zon.slots, 0..) |slotIndex, offset, i| {
            const rect = zhu.Rect.init(offset, zon.slotSize);
            const slot = store.get(slotIndex orelse continue) orelse continue;
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
            const slot = store.getPtr(index) orelse return;

            state = .{
                .source = .{ .bag = index },
                .bagIndex = index,
                .item = slot.*,
                .start = zhu.window.mouse,
            };
            return;
        }

        const barIndex = bar.hoveredSlot() orelse return;
        const bagIndex = bar.refs[barIndex] orelse return;
        const slot = store.getPtr(bagIndex) orelse return;

        state = .{
            .source = .{ .bar = barIndex },
            .bagIndex = bagIndex,
            .item = slot.*,
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
            .bag => |toIndex| bag.move(fromIndex, toIndex),
            .bar => |barIndex| bar.bind(barIndex, fromIndex),
        }
    }

    fn finishBar(fromBar: usize, fromBag: usize) void {
        switch (target() orelse {
            bar.refs[fromBar] = null;
            return;
        }) {
            .bag => |toIndex| bag.move(fromBag, toIndex),
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

        drawItemIcon(current.item.item, zhu.window.mouse);

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

pub fn activeItem() ?ItemEnum {
    return if (bar.item()) |stack| stack.item else null;
}

pub fn use(itemType: ItemEnum, count: u32) bool {
    if (count == 0) return true;

    var remaining = count;
    for (store.stacks) |*stack| {
        if (stack.count == 0 or stack.item != itemType) continue;

        const used = @min(stack.count, remaining);
        remaining -= used;
        if (remaining == 0) break;
    }
    if (remaining != 0) return false;

    remaining = count;
    for (store.stacks) |*stack| {
        if (stack.count == 0 or stack.item != itemType) continue;

        const used = @min(stack.count, remaining);
        stack.count -= used;
        remaining -= used;
        if (remaining == 0) return true;
    }
    unreachable;
}

pub fn update() void {
    const panelDragging = bag.drag != null;

    bag.update();
    if (panelDragging or bag.drag != null) {
        context.input.mouseCaptured = true;
        return;
    }

    if (updateUseItem()) {
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

fn updateUseItem() bool {
    if (itemDrag.state != null or bag.drag != null) return false;
    if (!context.input.mousePressed(.RIGHT)) return false;

    const index = hoveredBagIndex() orelse return false;
    switch (bag.useByIndex(index)) {
        .none => {},
        .full => context.notice.show(.item, "背包已满", .{}),
        .item => |value| context.notice.show(.item, "获得 {s} x{d}", .{
            factory.itemConfig(value.item).name,
            value.count,
        }),
    }
    return true;
}

fn hoveredBagIndex() ?usize {
    if (bag.hoveredSlotIndex()) |index| return index;

    const barIndex = bar.hoveredSlot() orelse return null;
    return bar.refs[barIndex];
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
        const slot = store.getPtr(index) orelse return null;
        return slot.item;
    }

    const barIndex = bar.hoveredSlot() orelse return null;
    const bagIndex = bar.refs[barIndex] orelse return null;
    const slot = store.getPtr(bagIndex) orelse return null;
    return slot.item;
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

fn pressMouse(button: zhu.mouse.Button) void {
    var ev = zhu.window.Event{
        .type = .MOUSE_DOWN,
        .mouse_button = button,
    };
    zhu.input.handle(&ev);
}

test "添加物品会合并并自动绑定快捷栏" {
    reset();

    _ = add(.strawberry, 7);
    _ = add(.strawberry, 3);

    try std.testing.expectEqual(.strawberry, activeItem().?);
    const index = bar.refs[bar.active].?;
    try std.testing.expectEqual(10, store.stacks[index].count);
}

test "右键背包槽会使用物品" {
    zhu.input.reset();
    defer zhu.input.reset();
    reset();
    defer reset();

    context.input.mouseCaptured = false;
    defer context.input.mouseCaptured = false;
    bag.closed = false;
    store.stacks[0] = .{ .item = .strawberry, .count = 2 };
    zhu.window.mouse = bag.position.add(bag.zon.slots[0]).add(.xy(1, 1));
    pressMouse(.RIGHT);

    update();

    try std.testing.expect(context.input.mouseCaptured);
    try std.testing.expectEqual(.strawberry, store.stacks[0].item);
    try std.testing.expectEqual(1, store.stacks[0].count);
    try std.testing.expectEqual(.strawberrySeed, store.stacks[1].item);
    try std.testing.expectEqual(3, store.stacks[1].count);
}

test "右键快捷栏会使用绑定的背包槽" {
    zhu.input.reset();
    defer zhu.input.reset();
    reset();
    defer reset();

    context.input.mouseCaptured = false;
    defer context.input.mouseCaptured = false;
    store.stacks[5] = .{ .item = .potato, .count = 1 };
    bar.refs[2] = 5;
    zhu.window.mouse = bar.zon.position.add(bar.zon.slots[2]).add(.xy(1, 1));
    pressMouse(.RIGHT);

    update();

    try std.testing.expect(context.input.mouseCaptured);
    try std.testing.expectEqual(.potatoSeed, store.stacks[5].item);
    try std.testing.expectEqual(3, store.stacks[5].count);
}

test "新增工具会占用独立槽位" {
    reset();

    try std.testing.expectEqual(0, add(.hoe, 1));
    try std.testing.expectEqual(0, add(.hoe, 1));

    try std.testing.expectEqual(.hoe, store.stacks[0].item);
    try std.testing.expectEqual(1, store.stacks[0].count);
    try std.testing.expectEqual(.hoe, store.stacks[1].item);
    try std.testing.expectEqual(1, store.stacks[1].count);
}

test "移动同类工具不会合并" {
    reset();

    store.stacks[0] = .{ .item = .hoe, .count = 1 };
    store.stacks[1] = .{ .item = .hoe, .count = 1 };

    bag.move(0, 1);

    try std.testing.expectEqual(1, store.stacks[0].count);
    try std.testing.expectEqual(1, store.stacks[1].count);
}

test "当前物品通过快捷栏引用读取库存槽" {
    reset();

    bar.active = 1;
    store.stacks[5] = .{ .item = .potatoSeed, .count = 2 };
    bar.refs[1] = 5;

    try std.testing.expectEqual(.potatoSeed, activeItem().?);
    try std.testing.expectEqual(2, store.stacks[5].count);

    store.stacks[5].count = 0;
    try std.testing.expectEqual(null, activeItem());
}

test "同一种物品只能绑定到一个快捷栏槽位" {
    reset();

    // Zig 版快捷栏按物品类型唯一绑定，避免同类物品占用多个快捷键。
    store.stacks[0] = .{ .item = .strawberrySeed, .count = 2 };
    store.stacks[2] = .{ .item = .strawberrySeed, .count = 4 };

    bar.bind(0, 0);
    bar.bind(3, 2);

    try std.testing.expectEqual(null, bar.refs[0]);
    try std.testing.expectEqual(2, bar.refs[3].?);
}

test "快捷栏拖到空快捷栏会移动绑定" {
    reset();

    store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    bar.bind(0, 0);

    bar.moveBinding(0, 4);

    try std.testing.expectEqual(null, bar.refs[0]);
    try std.testing.expectEqual(0, bar.refs[4].?);
}

test "快捷栏拖到已有快捷栏会交换绑定" {
    reset();

    store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    store.stacks[1] = .{ .item = .potato, .count = 3 };
    bar.bind(0, 0);
    bar.bind(4, 1);

    bar.moveBinding(0, 4);

    try std.testing.expectEqual(1, bar.refs[0].?);
    try std.testing.expectEqual(0, bar.refs[4].?);
}

test "拖动物品到空槽后快捷栏继续指向该物品" {
    reset();

    store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    bar.bind(2, 0);
    bar.active = 2;

    bag.move(0, 5);

    try std.testing.expectEqual(.strawberry, activeItem().?);
    try std.testing.expectEqual(5, store.stacks[5].count);
}

test "交换不同物品后快捷栏继续指向原物品" {
    reset();

    store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    store.stacks[1] = .{ .item = .potato, .count = 3 };
    bar.bind(0, 0);
    bar.bind(1, 1);

    bag.move(0, 1);

    bar.active = 0;
    try std.testing.expectEqual(.strawberry, activeItem().?);
    try std.testing.expectEqual(5, store.stacks[bar.refs[0].?].count);

    bar.active = 1;
    try std.testing.expectEqual(.potato, activeItem().?);
    try std.testing.expectEqual(3, store.stacks[bar.refs[1].?].count);
}

test "合并同类物品后快捷栏继续指向合并物品" {
    reset();

    store.stacks[0] = .{ .item = .strawberry, .count = 5 };
    store.stacks[1] = .{ .item = .strawberry, .count = 4 };
    bar.bind(0, 0);
    bar.active = 0;

    bag.move(0, 1);

    try std.testing.expectEqual(.strawberry, activeItem().?);
    try std.testing.expectEqual(9, store.stacks[bar.refs[0].?].count);
}

test "使用作物会消耗一个并产出种子" {
    reset();

    store.stacks[0] = .{ .item = .strawberry, .count = 2 };

    const result = bag.useByIndex(0);

    try std.testing.expectEqual(.strawberry, store.stacks[0].item);
    try std.testing.expectEqual(1, store.stacks[0].count);
    try std.testing.expectEqual(.strawberrySeed, store.stacks[1].item);
    try std.testing.expectEqual(3, store.stacks[1].count);

    const item = switch (result) {
        .item => |value| value,
        .none, .full => return error.TestExpectedEqual,
    };
    try std.testing.expectEqual(.strawberrySeed, item.item);
    try std.testing.expectEqual(3, item.count);
}

test "使用最后一个作物会优先回填原槽" {
    reset();

    store.stacks[0] = .{ .item = .potato, .count = 1 };
    bar.refs[0] = 0;

    const result = bag.useByIndex(0);

    try std.testing.expectEqual(.potatoSeed, store.stacks[0].item);
    try std.testing.expectEqual(3, store.stacks[0].count);
    try std.testing.expectEqual(0, bar.refs[0].?);
    try std.testing.expectEqual(.potatoSeed, activeItem().?);

    const item = switch (result) {
        .item => |value| value,
        .none, .full => return error.TestExpectedEqual,
    };
    try std.testing.expectEqual(.potatoSeed, item.item);
    try std.testing.expectEqual(3, item.count);
}

test "use 会在数量足够时扣除指定物品" {
    reset();

    store.stacks[0] = .{ .item = .strawberrySeed, .count = 2 };

    try std.testing.expect(!use(.potatoSeed, 1));
    try std.testing.expectEqual(@as(u32, 2), store.stacks[0].count);

    try std.testing.expect(use(.strawberrySeed, 1));
    try std.testing.expectEqual(@as(u32, 1), store.stacks[0].count);

    try std.testing.expect(!use(.strawberrySeed, 2));
    try std.testing.expectEqual(@as(u32, 1), store.stacks[0].count);
}

test "use 会先确认总数足够再跨槽扣除" {
    reset();

    store.stacks[0] = .{ .item = .strawberrySeed, .count = 1 };
    store.stacks[2] = .{ .item = .strawberrySeed, .count = 2 };

    try std.testing.expect(!use(.strawberrySeed, 4));
    try std.testing.expectEqual(@as(u32, 1), store.stacks[0].count);
    try std.testing.expectEqual(@as(u32, 2), store.stacks[2].count);

    try std.testing.expect(use(.strawberrySeed, 3));
    try std.testing.expectEqual(@as(u32, 0), store.stacks[0].count);
    try std.testing.expectEqual(@as(u32, 0), store.stacks[2].count);
}

test "使用物品产物优先回到原槽而不是第一个空槽" {
    reset();

    store.stacks[5] = .{ .item = .potato, .count = 1 };

    const result = bag.useByIndex(5);

    try std.testing.expectEqual(0, store.stacks[0].count);
    try std.testing.expectEqual(.potatoSeed, store.stacks[5].item);
    try std.testing.expectEqual(3, store.stacks[5].count);

    const item = switch (result) {
        .item => |value| value,
        .none, .full => return error.TestExpectedEqual,
    };
    try std.testing.expectEqual(.potatoSeed, item.item);
    try std.testing.expectEqual(3, item.count);
}

test "使用物品空间不足时不会修改背包" {
    reset();

    @memset(store.stacks, .{ .item = .potato, .count = 99 });
    store.stacks[0] = .{ .item = .strawberry, .count = 2 };

    const result = bag.useByIndex(0);

    try std.testing.expectEqual(UseResult.full, result);
    try std.testing.expectEqual(.strawberry, store.stacks[0].item);
    try std.testing.expectEqual(2, store.stacks[0].count);
    try std.testing.expectEqual(.potato, store.stacks[1].item);
    try std.testing.expectEqual(99, store.stacks[1].count);
}
