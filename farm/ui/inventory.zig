const zhu = @import("zhu");

const factory = @import("../factory.zig");
const input = @import("../input.zig");
const item = @import("item.zig");
const bag = @import("bag.zig");
const bar = @import("bar.zig");
const Inventory = @import("../global/Inventory.zig");
const Notice = @import("../global/Notice.zig");

const ItemEnum = @import("../component.zig").item.ItemEnum;
const Stack = Inventory.Stack;
const World = zhu.ecs.World;

var itemDrag: ItemDrag = .{};

pub fn init() void {
    reset();
}

pub fn reset() void {
    bag.reset();
    bar.reset();
    itemDrag.reset();
}

pub fn update(world: *World) void {
    const inv = world.getPtr(world.entity, Inventory).?;
    const notice = world.getPtr(world.entity, Notice).?;
    const panelDragging = bag.drag != null;

    bag.update(inv);
    if (panelDragging or bag.drag != null) {
        input.mouseCaptured = true;
        return;
    }

    if (updateUseItem(inv, notice)) {
        input.mouseCaptured = true;
        return;
    }

    bar.update(inv);
    itemDrag.update(inv);

    if (itemDrag.dragState != null or bag.drag != null or
        bag.click.captured or bar.click.captured)
    {
        input.mouseCaptured = true;
    }
}

pub fn draw(world: *World) void {
    const inv = world.getPtr(world.entity, Inventory).?;

    bag.draw(inv, itemDrag.hiddenBag());
    bar.draw(inv, itemDrag.hiddenBar());
    itemDrag.draw();
    drawTooltip(inv);
}

fn updateUseItem(inv: *Inventory, notice: *Notice) bool {
    if (itemDrag.dragState != null or bag.drag != null) return false;
    if (!input.mousePressed(.RIGHT)) return false;

    const index = hoveredBagIndex(inv) orelse return false;
    switch (inv.useAt(index)) {
        .none => {},
        .full => notice.show("背包已满", .{}),
        .item => |value| notice.show("获得 {s} x{d}", .{
            factory.itemConfig(value.item).name,
            value.count,
        }),
    }
    return true;
}

fn hoveredBagIndex(inv: *Inventory) ?usize {
    if (bag.hoveredSlotIndex(inv)) |index| return index;

    const barIndex = bar.hoveredSlot() orelse return null;
    return inv.hotbar[barIndex];
}

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

        if (bag.hoveredSlotIndex(inv)) |index| {
            const slot = inv.store.getPtr(index) orelse return;

            self.dragState = .{
                .source = .{ .bag = index },
                .bagIndex = index,
                .item = slot.*,
                .start = zhu.window.mouse,
            };
            return;
        }

        const barIndex = bar.hoveredSlot() orelse return;
        const bagIndex = inv.hotbar[barIndex] orelse return;
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
            .bag => |toIndex| _ = inv.moveSlot(fromIndex, toIndex),
            .bar => |barIndex| inv.bindHotbar(barIndex, fromIndex),
        }
    }

    fn finishBar(
        self: *ItemDrag,
        inv: *Inventory,
        fromBar: usize,
        fromBag: usize,
    ) void {
        switch (self.target(inv) orelse {
            inv.clearHotbar(fromBar);
            return;
        }) {
            .bag => |toIndex| _ = inv.moveSlot(fromBag, toIndex),
            .bar => |toBar| inv.moveHotbarBinding(fromBar, toBar),
        }
    }

    fn target(self: *ItemDrag, inv: *Inventory) ?Target {
        _ = self;
        if (bag.hoveredSlotIndex(inv)) |index| {
            return .{ .bag = index };
        }
        if (bar.hoveredSlot()) |index| return .{ .bar = index };
        return null;
    }

    fn hiddenBag(self: *const ItemDrag) ?usize {
        const current = self.dragState orelse return null;
        if (!current.moved) return null;
        return switch (current.source) {
            .bag => |source| source,
            .bar => null,
        };
    }

    fn hiddenBar(self: *const ItemDrag) ?usize {
        const current = self.dragState orelse return null;
        if (!current.moved) return null;
        return switch (current.source) {
            .bar => |source| source,
            .bag => null,
        };
    }

    fn draw(self: *ItemDrag) void {
        const current = self.dragState orelse return;
        if (!current.moved) return;

        zhu.camera.push(.window);
        defer zhu.camera.pop();

        // 拖拽预览半透明，对齐 CPP UIDragPreview 的 0.6 alpha。
        const icon = factory.itemConfig(current.item.item).icon;
        zhu.batch.drawImage(factory.resolveImage(icon), zhu.window.mouse, .{
            .size = icon.size,
            .anchor = .center,
            .color = .{ .a = 0.6 },
        });

        if (current.item.count <= 1) return;

        const rect = zhu.Rect.init(
            zhu.window.mouse.sub(bag.zon.slotSize.scale(0.5)),
            bag.zon.slotSize,
        );
        item.drawCount(current.item.count, rect);
    }
};

fn tooltipItem(inv: *Inventory) ?ItemEnum {
    if (itemDrag.dragState != null or bag.drag != null) return null;

    if (bag.hoveredSlotIndex(inv)) |index| {
        const slot = inv.store.getPtr(index) orelse return null;
        return slot.item;
    }

    const barIndex = bar.hoveredSlot() orelse return null;
    const bagIndex = inv.hotbar[barIndex] orelse return null;
    const slot = inv.store.getPtr(bagIndex) orelse return null;
    return slot.item;
}

fn drawTooltip(inv: *Inventory) void {
    const itemType = tooltipItem(inv) orelse return;
    item.drawTooltip(itemType, bag.zon.tooltip);
}
