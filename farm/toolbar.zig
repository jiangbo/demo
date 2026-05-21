const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const prefab = @import("prefab.zig");

const ItemEnum = component.ItemEnum;
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

const preset: Config = @import("zon/preset.zon");

const imagePath = "assets/farm-rpg/UI/Inventory/Slots.png";

pub const Item = struct { type: ItemEnum, count: u32 = 0 };

pub var slots: [preset.slotCount]Item = @splat(.{ .type = .hoe });
pub var index: u32 = 0;
var hoverIndex: ?usize = null;

pub fn init() void {
    _ = zhu.assets.loadImage(imagePath);
    index = 0;
    add(.hoe, 1);
    add(.water, 1);
    add(.seed, 99);
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
    return if (slots[index].count == 0) null else &slots[index];
}

pub fn update() void {
    if (zhu.input.key.pressed(._0)) index = slots.len - 1;
    const key1: usize = @intFromEnum(zhu.input.KeyCode._1);
    for (0..slots.len - 1) |key| {
        const keyCode: zhu.input.KeyCode = @enumFromInt(key1 + key);
        if (zhu.input.key.pressed(keyCode)) index = @intCast(key);
    }

    const pPos = panelPosition();
    const mousePos = zhu.window.mousePosition;
    hoverIndex = null;
    for (0..slots.len) |i| {
        const sPos = slotPosition(i, pPos);
        const area = zhu.Rect.init(sPos, .xy(preset.slotSize, preset.slotSize));
        if (area.contains(mousePos)) {
            hoverIndex = i;
            if (zhu.window.mouse.released(.LEFT)) {
                index = @intCast(i);
                zhu.audio.playSound("assets/audio/UI_button08.ogg");
            }
            break;
        }
    }
}

const slotsWidth: f32 = preset.slotCount * preset.slotSize + (preset.slotCount - 1) * preset.spacing;
const panelWidth: f32 = slotsWidth + preset.panelPadding * 2;
const panelHeight: f32 = preset.slotSize + preset.panelPadding * 2;

fn panelPosition() zhu.Vector2 {
    return .xy(
        (zhu.camera.size.x - panelWidth) / 2,
        zhu.camera.size.y - panelHeight - preset.bottomMargin,
    );
}

fn slotPosition(i: usize, panelPos: zhu.Vector2) zhu.Vector2 {
    const startX = panelPos.x + preset.panelPadding;
    const startY = panelPos.y + preset.panelPadding;
    const x = startX + @as(f32, @floatFromInt(i)) * (preset.slotSize + preset.spacing);
    return .xy(x, startY);
}

pub fn draw() void {
    // const uiImage = zhu.assets.getImage(preset.imageId).?;
    // const panelPos = panelPosition();
    // zhu.batch.drawNine(uiImage.sub(preset.panel.rect), .init(panelPos, .xy(panelWidth, panelHeight)), preset.panel.nine);

    // for (slots, 0..) |slot, i| {
    //     const slotPos = slotPosition(i, panelPos);

    //     zhu.batch.drawNine(uiImage.sub(preset.slot.rect), .init(slotPos, .xy(preset.slotSize, preset.slotSize)), preset.slot.nine);

    //     if (slot.count > 0) {
    //         const iconMargin = preset.slotSize * 0.1;
    //         const iconPos = slotPos.add(.xy(iconMargin, iconMargin));
    //         const iconSize = zhu.Vector2.square(preset.slotSize * 0.8);

    //         drawItemIcon(slot.type, iconPos, iconSize);
    //         if (slot.count > 1) drawItemCount(slot.count, iconPos, iconSize);
    //     }

    //     if (i == index) {
    //         zhu.batch.drawNine(
    //             uiImage.sub(preset.selected.rect),
    //             .init(slotPos, .xy(preset.slotSize, preset.slotSize)),
    //             preset.selected.nine,
    //         );
    //     }
    // }
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
