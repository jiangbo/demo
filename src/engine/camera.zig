const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const window = @import("window.zig");
const text = @import("text.zig");
const batch = @import("batch.zig");

const Texture = gpu.Texture;
const Vector = math.Vector;
const Vector2 = math.Vector2;
const Rect = math.Rect;
const Color = math.Vector4;
pub const Vertex = batch.QuadVertex;

pub var mode: enum { world, local } = .world;
pub var position: math.Vector = .zero;
pub var whiteTexture: gpu.Texture = undefined;

var startDraw: bool = false;

pub fn init(buffer: []Vertex) void {
    batch.init(window.logicSize, buffer);
}

pub fn initWithWhiteTexture(buffer: []Vertex) void {
    init(buffer);
    const data: [64]u8 = [1]u8{0xFF} ** 64;
    whiteTexture = gpu.createTexture(.init(4, 4), &data);
}

pub fn toWorld(windowPosition: Vector) Vector {
    return windowPosition.add(position);
}

pub fn toWindow(worldPosition: Vector) Vector {
    return worldPosition.sub(position);
}

pub fn beginDraw(color: gpu.Color) void {
    batch.beginDraw(color);
    startDraw = true;
    text.count = 0;
}

pub fn debugDraw(area: math.Rect) void {
    drawRect(area, .{ .color = .{ .x = 1, .z = 1, .w = 0.4 } });
}

pub fn draw(texture: gpu.Texture, pos: math.Vector) void {
    drawOption(texture, pos, .{});
}

pub fn drawFlipX(texture: Texture, pos: Vector, flipX: bool) void {
    drawOption(texture, pos, .{ .flipX = flipX });
}

pub const LineOption = struct { color: Color = .white, width: f32 = 1 };

/// 绘制轴对齐的线
pub fn drawAxisLine(start: Vector, end: Vector, option: LineOption) void {
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
pub fn drawLine(start: Vector, end: Vector, option: LineOption) void {
    const vector = end.sub(start);
    const y = start.y - option.width / 2;

    drawOption(whiteTexture, .init(start.x, y), .{
        .size = .init(vector.length(), option.width),
        .color = option.color,
        .radian = vector.atan2(),
        .pivot = .init(0, 0.5),
    });
}

pub fn drawRectBorder(area: Rect, width: f32, rectColor: Color) void {
    const color = RectOption{ .color = rectColor };
    drawRect(.init(area.min, .init(area.size.x, width)), color); // 上
    var start = area.min.addY(area.size.y - width);
    drawRect(.init(start, .init(area.size.x, width)), color); // 下
    const size: Vector2 = .init(width, area.size.y - 2 * width);
    drawRect(.init(area.min.addY(width), size), color); // 左
    start = area.min.addXY(area.size.x - width, width);
    drawRect(.init(start, size), color); // 右
}

const RectOption = struct { color: Color = .white, radian: f32 = 0 };
pub fn drawRect(area: math.Rect, option: RectOption) void {
    drawOption(whiteTexture, area.min, .{
        .size = area.size,
        .color = option.color,
        .radian = option.radian,
    });
}

pub const Option = batch.Option;
pub fn drawOption(texture: Texture, pos: Vector, option: Option) void {
    if (!startDraw) @panic("need begin draw");

    var worldPos = pos;
    if (mode == .local) worldPos = pos.add(position);
    batch.drawOption(texture, worldPos, option);
}

pub fn endDraw() void {
    startDraw = false;
    batch.endDraw(position);
}

pub fn scissor(area: math.Rect) void {
    const min = area.min.mul(window.ratio);
    const size = area.size.mul(window.ratio);
    batch.encodeCommand(.{ .scissor = .{ .min = min, .size = size } });
}
pub fn resetScissor() void {
    batch.encodeCommand(.{ .scissor = .fromMax(.zero, window.clientSize) });
}

pub fn encodeScaleCommand(scale: Vector) void {
    batch.setScale(scale);
    batch.startNewDrawCommand();
}

pub const frameStats = gpu.frameStats;
pub const queryFrameStats = gpu.queryFrameStats;
pub const queryBackend = gpu.queryBackend;
pub const drawNumber = text.drawNumber;
pub const drawText = text.draw;
pub const drawTextColor = text.drawColor;
pub const drawTextOptions = text.drawOption;
pub const computeTextWidth = text.computeTextWidth;
pub const imageDrawCount = batch.imageDrawCount;

pub fn textDrawCount() usize {
    return text.count;
}
