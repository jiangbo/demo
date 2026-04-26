const std = @import("std");
const zhu = @import("zhu");

const batch = zhu.batch;
const text = zhu.text;

const com = @import("component.zig");
const spawn = @import("spawn.zig");
const ctx = @import("context.zig");
const map = @import("map.zig");

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
    if (ctx.selected != null) return;

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

    if (zhu.window.mouse.pressed(.LEFT)) {
        if (hoveredIndex) |idx| {
            const unit = &units[idx];
            if (ctx.canAffordCost(unit.cost)) {
                ctx.selected = unit.class;
                hoveredIndex = null;
            }
        }
    }
}

pub fn draw() void {
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

    if (ctx.selected) |playerEnum| drawPrepare(playerEnum);
}

/// 绘制准备出击单位（跟随鼠标）
fn drawPrepare(playerEnum: com.PlayerEnum) void {
    const template = &spawn.playerZon[@intFromEnum(playerEnum)];
    const mousePos = zhu.window.mousePosition;
    const found = map.findPlace(template.attackKind, mousePos);

    // 远程单位显示攻击范围
    if (template.attackKind == .ranged) {
        const range = template.range;
        const diameter = range * 2;
        const circle = zhu.getImage("circle.png");
        zhu.batch.drawImage(circle, mousePos.sub(.xy(range, range)), .{
            .size = .xy(diameter, diameter),
            .color = .rgba(0, 1, 0, 0.2),
        });
    }

    // 绘制准备单位精灵（合法绿色，非法红色）
    const size = template.image.size;
    const image = zhu.assets.loadImage(template.image.path, size);
    const sub = image.sub(.init(.zero, template.size));
    zhu.batch.drawImage(sub, mousePos.add(template.offset), .{
        .color = if (found != null) .green else .red,
    });
}
