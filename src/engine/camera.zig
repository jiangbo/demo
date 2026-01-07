const std = @import("std");

const math = @import("math.zig");
const text = @import("text.zig");
const assets = @import("assets.zig");
const graphics = @import("graphics.zig");

const Color = graphics.Color;
const Vector2 = math.Vector2;
const ImageId = graphics.ImageId;
const String = text.String;

pub var mode: enum { world, local } = .world;
pub var position: Vector2 = .zero;

var startDraw: bool = false;

pub fn toWorld(windowPosition: Vector2) Vector2 {
    return windowPosition.add(position);
}

pub fn toWindow(worldPosition: Vector2) Vector2 {
    return worldPosition.sub(position);
}

pub fn beginDraw(color: Color) void {
    graphics.beginDraw(color);
    startDraw = true;
    text.count = 0;
}

pub fn debugDraw(area: math.Rect) void {
    drawRect(area, .{ .color = .{ .x = 1, .z = 1, .w = 0.4 } });
}

pub fn draw(image: ImageId, pos: math.Vector2) void {
    drawImageOption(image, pos, .{});
}

pub fn drawFlipX(image: ImageId, pos: Vector2, flipX: bool) void {
    drawImageOption(image, pos, .{ .flipX = flipX });
}

pub const LineOption = struct { color: Color = .white, width: f32 = 1 };

/// 绘制轴对齐的线
pub fn drawAxisLine(start: Vector2, end: Vector2, option: LineOption) void {
    const rectOption = RectOption{ .color = option.color };
    const halfWidth = -@floor(option.width / 2);
    if (start.x == end.x) {
        const size = Vector2.init(option.width, end.y - start.y);
        drawRect(.init(start.addX(halfWidth), size), rectOption);
    } else if (start.y == end.y) {
        const size = Vector2.init(end.x - start.x, option.width);
        drawRect(.init(start.addY(halfWidth), size), rectOption);
    }
}

/// 绘制任意线
pub fn drawLine(start: Vector2, end: Vector2, option: LineOption) void {
    const vector = end.sub(start);
    const y = start.y - option.width / 2;

    drawImageOption(graphics.whiteImage, .init(start.x, y), .{
        .size = .init(vector.length(), option.width),
        .color = option.color,
        .radian = vector.atan2(),
        .pivot = .init(0, 0.5),
    });
}

pub fn drawRectBorder(area: math.Rect, width: f32, c: Color) void {
    const color = RectOption{ .color = c };
    drawRect(.init(area.min, .init(area.size.x, width)), color); // 上
    var start = area.min.addY(area.size.y - width);
    drawRect(.init(start, .init(area.size.x, width)), color); // 下
    const size: Vector2 = .init(width, area.size.y - 2 * width);
    drawRect(.init(area.min.addY(width), size), color); // 左
    start = area.min.addXY(area.size.x - width, width);
    drawRect(.init(start, size), color); // 右
}

pub const RectOption = struct { color: Color = .white, radian: f32 = 0 };
pub fn drawRect(area: math.Rect, option: RectOption) void {
    drawImageOption(graphics.whiteImage, area.min, .{
        .size = area.size,
        .color = option.color,
        .radian = option.radian,
    });
}

pub const Option = graphics.Option;
pub fn drawImageOption(image: ImageId, pos: Vector2, option: Option) void {
    if (!startDraw) @panic("need begin draw");

    var worldPos = pos;
    if (mode == .local) worldPos = pos.add(position);
    graphics.draw(graphics.getImage(image), worldPos, option);
}

pub fn drawNumber(number: anytype, pos: Vector2) void {
    drawNumberColor(number, pos, .one);
}

pub fn drawNumberColor(number: anytype, pos: Vector2, color: Color) void {
    var textBuffer: [15]u8 = undefined;
    const string = text.format(&textBuffer, "{d}", .{number});
    drawTextColor(string, pos, color);
}

pub fn drawText(string: String, pos: math.Vector) void {
    drawTextOption(string, pos, .{});
}

pub fn drawTextCenter(str: String, pos: Vector2, option: Option) void {
    const width = text.computeTextWidthOption(str, option);
    drawTextOption(text, .init(pos.x - width / 2, pos.y), option);
}

pub fn drawTextRight(str: String, pos: Vector2, option: Option) void {
    const width = text.computeTextWidthOption(str, option);
    drawTextOption(str, .init(pos.x - width, pos.y), option);
}

pub fn drawTextFmt(comptime fmt: String, pos: Vector2, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    drawTextOption(text.format(&buffer, fmt, args), pos);
}

pub fn drawTextColor(str: String, pos: Vector2, color: Color) void {
    drawTextOption(str, pos, .{ .color = color });
}

pub fn drawTextOption(str: String, pos: Vector2, option: text.Option) void {
    var worldPos = pos;
    if (mode == .local) worldPos = pos.add(position);
    text.draw(str, worldPos, option);
}

pub fn endDraw() void {
    startDraw = false;
    graphics.endDraw(position);
}

pub const imageDrawCount = graphics.imageDrawCount;
pub const computeTextWidth = text.computeTextWidth;

pub fn textDrawCount() usize {
    return text.count;
}
