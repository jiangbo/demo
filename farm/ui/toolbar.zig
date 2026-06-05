const std = @import("std");
const zhu = @import("zhu");

const component = @import("../component.zig");
const prefab = @import("../prefab.zig");

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

pub const Item = struct { type: ItemEnum, count: u32 = 0 };

const zon: Config = @import("../zon/preset.zon");

pub var slots: [zon.slotCount]Item = @splat(.{ .type = .hoe });
pub var slotIndex: usize = 0;

var panelPosition: zhu.Vector2 = undefined; // 初始位置
const slotWidth: f32 = zon.slotCount * (zon.slotSize + zon.spacing);
const panelWidth: f32 = slotWidth - zon.spacing + zon.panelPadding * 2;
const panelHeight: f32 = zon.panelPadding * 2 + zon.slotSize;

pub fn enter() void {
    slots = @splat(.{ .type = .hoe, .count = 0 });
    slotIndex = 0;
    add(.hoe, 1);
    add(.water, 1);
    add(.seed, 99);

    panelPosition = zhu.Vector2{
        .x = (zhu.window.size.x - panelWidth) / 2,
        .y = zhu.window.size.y - panelHeight - zon.bottomMargin,
    };
}

pub fn add(itemType: ItemEnum, count: u32) void {
    const config = prefab.item(itemType);

    var remaining: u32 = count;
    for (&slots) |*slot| { // 先尝试叠加到已有的同类型物品上
        if (slot.count == 0 or slot.type != itemType) continue;

        const space = config.limit - slot.count;
        if (space == 0) continue;
        const minCount = @min(space, remaining);
        slot.count += minCount;
        remaining -= minCount;
        if (remaining == 0) break;
    }

    for (&slots) |*slot| { // 再尝试放到空槽位
        if (slot.count > 0 or remaining == 0) continue;

        const minCount = @min(config.limit, remaining);
        slot.* = .{ .type = itemType, .count = minCount };
        remaining -= minCount;
    }
}

pub fn active() ?*Item {
    return if (slots[slotIndex].count == 0) null else &slots[slotIndex];
}

pub fn update() void {
    if (zhu.key.pressed(._0)) slotIndex = slots.len - 1;
    const key1: usize = @intFromEnum(zhu.key.Code._1);
    for (0..slots.len - 1) |key| {
        const keyCode: zhu.key.Code = @enumFromInt(key1 + key);
        if (zhu.key.pressed(keyCode)) slotIndex = @intCast(key);
    }

    const start = panelPosition.add(.square(zon.panelPadding));
    for (0..slots.len) |i| {
        const position = slotPosition(@floatFromInt(i), start);
        const rect = zhu.Rect.init(position, .square(zon.slotSize));
        if (!rect.contains(zhu.window.mouse)) continue;

        if (zhu.mouse.released(.LEFT)) {
            slotIndex = i;
            zhu.audio.playSound("assets/audio/UI_button08.ogg");
            break;
        }
    }
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
    for (slots, 0..) |slot, i| {
        const position = slotPosition(@floatFromInt(i), start);
        { // 绘制槽位
            const image = panelImage.sub(zon.slot.rect);
            const rect = zhu.Rect.init(position, .square(zon.slotSize));
            zhu.batch.drawNine(image, rect, zon.slot.nine);
        }

        if (slot.count > 0) {
            const iconSize = prefab.item(slot.type).icon.size;
            const iconOffset = zon.slotSize - iconSize.x;
            const iconPosition = position.add(.square(@round(iconOffset / 2)));

            drawItemIcon(slot.type, iconPosition, iconSize);

            if (slot.count > 1) drawItemCount(slot.count, iconPosition, iconSize);
        }

        if (i == slotIndex) {
            const image = panelImage.sub(zon.selected.rect);
            const rect = zhu.Rect.init(position, .square(zon.slotSize));
            zhu.batch.drawNine(image, rect, zon.selected.nine);
        }
    }
}

fn drawItemIcon(itemType: ItemEnum, position: zhu.Vector2, size: zhu.Vector2) void {
    const image = prefab.resolveImage(prefab.item(itemType).icon);
    zhu.batch.drawImage(image, position, .{ .size = size });
}

fn drawItemCount(count: u32, position: zhu.Vector2, size: zhu.Vector2) void {
    const pos = position.add(size).sub(.square(1));
    zhu.text.drawFormat("{d}", pos, .{count}, .{ .alignment = .one });
}
