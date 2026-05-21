const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const prefab = @import("prefab.zig");

const ItemEnum = component.ItemEnum;
const NineOption = zhu.batch.NineOption;

pub const Item = struct { type: ItemEnum, count: u32 = 0 };

pub var slots: [10]Item = @splat(.{ .type = .hoe });
pub var index: u32 = 0;

pub fn init() void {
    index = 0;
    add(.hoe, 1);
    add(.water, 1);
    add(.seed, 99);
}

pub fn add(itemType: ItemEnum, count: u32) void {
    const item_config = prefab.item(itemType);

    var remaining: u32 = count;
    for (&slots) |*slot| { // 先尝试叠加到已有的同类型物品上
        if (slot.count == 0 or slot.type != itemType) continue;

        const space = item_config.limit - slot.count;
        if (space == 0) continue;
        const minCount = @min(space, remaining);
        slot.count += minCount;
        remaining -= minCount;
        if (remaining == 0) break;
    }

    for (&slots) |*slot| { // 再尝试放到空槽位
        if (slot.count > 0 or remaining == 0) continue;

        const minCount = @min(item_config.limit, remaining);
        slot.* = .{ .type = itemType, .count = minCount };
        remaining -= minCount;
    }
}

pub fn active() ?*Item {
    return if (slots[index].count == 0) null else &slots[index];
}

pub fn update() void {
    if (zhu.input.key.pressed(._0)) index = slots.len - 1;
    const key1: usize = @intFromEnum(zhu.input.KeyCode._1);
    for (0..slots.len - 1) |key| {
        const keyCode: zhu.input.KeyCode = @enumFromInt(key1 + key);
        if (zhu.input.key.pressed(keyCode)) index = @intCast(key);
    }
}

const uiImagePath = "assets/farm-rpg/UI/Inventory/Slots.png";

const slotSize: f32 = 16;
const spacing: f32 = 2;
const slotCount: f32 = 10;
const panelPadding: f32 = 4;
const bottomMargin: f32 = 2.5;
const slotsWidth: f32 = slotCount * slotSize + (slotCount - 1) * spacing;
const panelWidth: f32 = slotsWidth + panelPadding * 2;
const panelHeight: f32 = slotSize + panelPadding * 2;

const panelRect: zhu.Rect = .init(.xy(6, 105), .xy(164, 28));
const slotRect: zhu.Rect = .init(.xy(151, 38), .xy(18, 18));
const selectedRect: zhu.Rect = .init(.xy(119, 6), .xy(18, 18));

const panelNine: NineOption = .{
    .topLeft = .xy(7, 7),
    .bottomRight = .xy(7, 6),
};
const slotNine: NineOption = .{
    .topLeft = .xy(2, 2),
    .bottomRight = .xy(2, 3),
};
const selectedNine: NineOption = .{
    .topLeft = .xy(4, 4),
    .bottomRight = .xy(4, 4),
};

pub fn draw() void {
    const uiImage = zhu.assets.loadImage(uiImagePath);
    const panelPos = zhu.Vector2.xy(
        (zhu.camera.size.x - panelWidth) / 2,
        zhu.camera.size.y - panelHeight - bottomMargin,
    );
    zhu.batch.drawNine(
        uiImage.sub(panelRect),
        .init(panelPos, .xy(panelWidth, panelHeight)),
        panelNine,
    );

    const startX = panelPos.x + panelPadding;
    const startY = panelPos.y + panelPadding;

    for (slots, 0..) |slot, i| {
        const x = startX + @as(f32, @floatFromInt(i)) * (slotSize + spacing);
        const y = startY;
        const slotPos = zhu.Vector2.xy(x, y);

        zhu.batch.drawNine(
            uiImage.sub(slotRect),
            .init(slotPos, .xy(slotSize, slotSize)),
            slotNine,
        );

        if (slot.count > 0) {
            const iconMargin = slotSize * 0.1;
            const iconPos = slotPos.add(.xy(iconMargin, iconMargin));
            const iconSize = zhu.Vector2.square(slotSize * 0.8);

            drawItemIcon(slot.type, iconPos, iconSize);
            if (slot.count > 1) drawItemCount(slot.count, iconPos, iconSize);
        }

        if (i == index) {
            zhu.batch.drawNine(
                uiImage.sub(selectedRect),
                .init(slotPos, .xy(slotSize, slotSize)),
                selectedNine,
            );
        }
    }
}

fn drawItemIcon(itemType: ItemEnum, pos: zhu.Vector2, size: zhu.Vector2) void {
    const config = prefab.item(itemType);
    const image = prefab.resolveImage(config.icon);
    zhu.batch.drawImage(image, pos, .{ .size = size });
}

fn drawItemCount(count: u32, iconPos: zhu.Vector2, iconSize: zhu.Vector2) void {
    var buffer: [15]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}", .{count}) catch return;
    const padding: f32 = 1;
    const textSize: f32 = 8;
    const x = iconPos.x + iconSize.x - zhu.text.computeTextWidth(text) - padding;
    const y = iconPos.y + iconSize.y - textSize - padding;
    zhu.text.drawColor(text, .xy(x, y), zhu.Color.white);
}
