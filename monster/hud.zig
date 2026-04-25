const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const text = zhu.text;

const com = @import("component.zig");
const spawn = @import("spawn.zig");
const ctx = @import("context.zig");

const ImageArea = struct {
    name: []const u8,
    image: [:0]const u8,
    rect: zhu.Rect,
};

const UiZon = struct {
    icon: []const ImageArea,
    border: []const ImageArea,
    face: []const ImageArea,
    padding: f32,
    frameSize: zhu.Vector2,
    fontOffset: zhu.Vector2,
};

const SessionData = struct {
    level: u32,
    point: u32,
    units: []const Unit,
};

const Unit = struct {
    face: u32,
    class: com.PlayerEnum,
    level: f32,
    rarity: f32,
    position: zhu.Vector2 = .zero,
    cost: u8 = 0,
};

const uiZon: UiZon = @import("zon/ui.zon");
const ctxZon: SessionData = @import("zon/context.zon");
var units: [ctxZon.units.len]Unit = ctxZon.units[0..].*;

var backgroundRect: zhu.Rect = undefined;
var hoveredIndex: ?u8 = null;

pub fn init() void {
    // 计算背景条宽度和起始位置
    computeBackgroundRect(@floatFromInt(ctxZon.units.len));
    // 计算每个头像的位置
    computeUnitPositions();
}

fn computeBackgroundRect(count: f32) void {
    const padding = uiZon.padding;
    const size = uiZon.frameSize;

    // 计算总宽度和起始位置
    const totalWidth = (size.x + padding) * count + padding;
    const startX = (zhu.window.size.x - totalWidth) / 2;
    const startY = zhu.window.size.y - size.y - 2 * padding;

    backgroundRect = .{
        .min = .xy(startX, startY - padding), // 再往上挪一点，给边框留空间
        .size = .xy(totalWidth, size.y + 2 * padding),
    };
}

fn computeUnitPositions() void {
    for (&units) |*unit| {
        const class: u8 = @intFromEnum(unit.class);
        var cost: f32 = @floatFromInt(spawn.playerZon[class].cost);
        const levelScale = 0.95 + 0.05 * unit.level;
        const rarityScale = 0.9 + 0.1 * unit.rarity;
        cost = @round(cost * levelScale * rarityScale);

        unit.cost = @intFromFloat(cost);
    }
    std.mem.sort(Unit, &units, {}, struct {
        fn lessThan(_: void, a: Unit, b: Unit) bool {
            return a.cost < b.cost;
        }
    }.lessThan);

    const padding = uiZon.padding;
    const size = uiZon.frameSize;
    const start = backgroundRect.min.addXY(padding, padding);
    for (&units, 0..) |*unit, i| {
        const index: f32 = @floatFromInt(i);
        const offset = (size.x + padding) * index;
        unit.position = .xy(start.x + offset, start.y);
    }
}

pub fn deinit() void {}

pub fn update() void {
    const mousePos = zhu.window.mousePosition;

    for (&units, 0..) |*unit, i| {
        const rect: zhu.Rect = .init(unit.position, uiZon.frameSize);
        if (rect.contains(mousePos)) {
            if (hoveredIndex == null or hoveredIndex.? != i) {
                zhu.audio.playSound("assets/audio/Fantasy_UI (1).ogg");
            }
            hoveredIndex = @intCast(i);
            break;
        }
    } else hoveredIndex = null;

    // // 处理输入
    // if (zhu.window.mouse.pressed(.LEFT)) {
    //     if (hoveredIndex) |idx| {
    //         const slot = &slots[idx];
    //         if (session.canAfford(slot.class)) {
    //             const current = session.getSelected();
    //             if (current != null and current.? == slot.class) {
    //                 session.setSelected(null); // 再次点击取消选择
    //             } else {
    //                 session.setSelected(slot.class);
    //             }
    //         }
    //     }
    // } else if (zhu.window.mouse.pressed(.RIGHT)) {
    //     session.setSelected(null);
    // }
}

pub fn draw() void {
    // // const selected = session.getSelected();
    // const selected = false;
    // const gold = session.getGold();

    // 背景条
    batch.drawRect(backgroundRect, .{ .color = .gray(0.1, 0.1) });

    for (&units) |unit| {
        const class: u8 = @intFromEnum(unit.class);

        // 绘制头像
        const face = uiZon.face[unit.face];
        var image = zhu.assets.loadImage(face.image, .zero);
        batch.drawImage(image.sub(face.rect), unit.position, .{
            .size = uiZon.frameSize,
        });

        // 绘制边框
        const border = uiZon.border[if (unit.rarity > 1) 1 else 0];
        image = zhu.assets.loadImage(border.image, .zero);
        batch.drawImage(image.sub(border.rect), unit.position, .{
            .size = uiZon.frameSize,
        });

        // 绘制职业
        const icon = uiZon.icon[class];
        image = zhu.assets.loadImage(icon.image, .zero);
        batch.drawImage(image.sub(icon.rect), unit.position, .{
            .size = uiZon.frameSize.scale(0.5),
        });

        // 绘制消耗
        const pos = unit.position.add(uiZon.fontOffset);
        text.drawNumberColor(unit.cost, pos, .yellow);

        if (!ctx.canAffordCost(unit.cost)) {
            batch.drawRect(.init(unit.position, uiZon.frameSize), .{
                .color = .rgba(0, 0, 0, 0.2),
            });
        }
    }

    const currentCost: u32 = @intFromFloat(@floor(ctx.cost));
    text.drawColor("COST:", .xy(24, 24), .yellow);
    text.drawNumberColor(currentCost, .xy(120, 24), .white);

    // // 第 5 层：状态叠加层（白色纹理，批量绘制）
    // for (slots, 0..) |slot, i| {
    //     const isSelected = selected != null and selected.? == slot.class;
    //     const isHovered = hoveredIndex == i;
    //     const canAfford = gold >= slot.cost;

    //     // 选中高亮
    //     if (isSelected) {
    //         batch.drawRect(slot.rect, .{ .color = .rgba(1, 1, 0, 0.3) });
    //     }

    //     // 悬停高亮
    //     if (isHovered and !isSelected) {
    //         batch.drawRect(slot.rect, .{ .color = .rgba(1, 1, 1, 0.15) });
    //     }

    //     // 金币不足遮罩
    //     if (!canAfford) {
    //         batch.drawRect(slot.rect, .{ .color = .rgba(0, 0, 0, 0.5) });
    //     }
    // }

    // 金币显示（右上角）
    // text.drawColor("金币:", .xy(1400, 10), .yellow);
    // text.drawNumberColor(gold, .xy(1500, 10), .white);
}

pub fn isBarHovered() bool {
    return hoveredIndex != null;
}

pub fn getSelected() ?com.PlayerEnum {
    return null;
    // return session.getSelected();
}
