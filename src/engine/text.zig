const std = @import("std");

const math = @import("math.zig");
const graphics = @import("graphics.zig");
const batch = @import("batch.zig");

const Image = graphics.Image;
const Vector2 = math.Vector2;
const Color = graphics.Color;
pub const String = []const u8;

pub const Font = struct {
    size: f32,
    lineHeight: f32,
    chars: []const Char,
};

pub const Char = struct {
    id: u32,
    area: math.Rect,
    offset: Vector2,
};

var commandArray: [8]batch.Command = undefined;
var layered: bool = false;

var invalidIndex: usize = 0;

var font: Font = undefined;
var fontImage: graphics.Image = undefined;
var fontScale: f32 = undefined;
var halfAdvance: f32 = undefined; // 英文只需要前进半个距离

pub fn init(image: Image, zon: Font) void {
    font = zon;
    fontImage = image;
    invalidIndex = binarySearch('?').?;
    halfAdvance = font.size / 2;
    changeFontSize(font.size);
}

pub fn changeFontSize(size: f32) void {
    fontScale = size / font.size;
}

pub fn enableLayer(vertices: []batch.Vertex) *batch.Layer {
    const defaultLayer = batch.layers.getPtrConst(.default);
    const textLayer = batch.layers.getPtr(.text);

    textLayer.pipeline = defaultLayer.pipeline;
    textLayer.sampler = defaultLayer.sampler;
    textLayer.commands = .initBuffer(&commandArray);
    textLayer.vertices = .initBuffer(vertices);
    textLayer.vertexHandle = batch.createVertexHandle(vertices);
    layered = true;
    return textLayer;
}

fn binarySearch(unicode: u32) ?usize {
    return std.sort.binarySearch(Char, font.chars, unicode, struct {
        fn compare(a: u32, b: Char) std.math.Order {
            return std.math.order(a, b.id);
        }
    }.compare);
}

pub fn searchChar(code: u32) *const Char {
    return &font.chars[binarySearch(code) orelse invalidIndex];
}

pub const Option = struct {
    scale: Vector2 = .one, // 基于默认字号的缩放
    color: graphics.Color = .white, // 文字的颜色
    max: f32 = std.math.floatMax(f32), // 最大宽度，超过换行
    spacing: f32 = 0, // 文字间的间距
    alignment: ?Vector2 = null, // 文字对齐
    layer: ?batch.Layer.Name = null, // 绘制的层
};

pub fn drawNumber(number: anytype, pos: Vector2, option: Option) void {
    var textBuffer: [15]u8 = undefined;
    const string = format(&textBuffer, "{d}", .{number});
    drawString(string, pos, option);
}

// zig fmt: off
pub fn drawFormat(comptime fmt: String, pos: Vector2, args: anytype,
    option: Option) void {
// zig fmt: on
    var buffer: [1024]u8 = undefined;
    drawString(format(&buffer, fmt, args), pos, option);
}

const Utf8View = std.unicode.Utf8View;
pub fn drawString(text: String, position: Vector2, option: Option) void {
    if (text.len == 0) return;
    const scale = option.scale.scale(fontScale);
    const height = font.lineHeight * scale.y;
    var pos = position;
    if (option.alignment) |a| { // 计算文字的对齐
        pos = pos.sub(measure(text, option).mul(a));
    }

    var width: f32, const startX = .{ 0, pos.x };
    var iterator = Utf8View.initUnchecked(text).iterator();
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') {
            width, pos = .{ 0, .xy(startX, pos.y + height) };
            continue;
        }

        const advance = charAdvance(code, scale.x);
        if (width > 0) {
            if (width + option.spacing + advance > option.max) {
                width, pos = .{ 0, .xy(startX, pos.y + height) };
            } else {
                width += option.spacing;
                pos = pos.addX(option.spacing);
            }
        }
        width += advance;

        const char = searchChar(code);
        const image = fontImage.sub(char.area);
        batch.drawImage(image, pos.add(char.offset.mul(scale)), .{
            .size = char.area.size.mul(scale),
            .color = option.color,
            .layer = option.layer orelse if (layered) .text else .default,
        });
        graphics.stats.text += 1;
        pos = .xy(startX + width, pos.y);
    }
}

pub fn measure(text: String, option: Option) Vector2 {
    if (text.len == 0) return .zero;
    const scale = option.scale.scale(fontScale);
    const height = font.lineHeight * scale.y;

    var max: f32, var line: f32, var width: f32 = .{ 0, 1, 0 };
    var iterator = Utf8View.initUnchecked(text).iterator();
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') {
            line, width = .{ line + 1, 0 };
            continue;
        }

        const advance = charAdvance(code, scale.x);
        if (width > 0) {
            if (width + option.spacing + advance > option.max) {
                line, width = .{ line + 1, 0 };
            } else width += option.spacing;
        }
        width += advance;
        max = @max(max, width);
    }

    return .xy(max, line * height);
}

pub fn lineHeight(option: Option) f32 {
    return font.lineHeight * fontScale * option.scale.y;
}

pub fn sizeToScale(size: f32) Vector2 {
    return .square(size / (font.size * fontScale));
}

fn charAdvance(code: u32, scale: f32) f32 {
    const advance = if (code < 128) halfAdvance else font.size;
    return advance * scale;
}

pub fn computeTextCount(text: String) usize {
    var iterator = Utf8View.initUnchecked(text).iterator();
    var total: usize = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code != '\n') total += 1;
    }
    return total;
}

pub fn encodeUtf8(buffer: []u8, unicode: []const u21) []u8 {
    var len: usize = 0;
    for (unicode) |code| {
        // 将单个 unicode 编码为 utf8
        len += std.unicode.utf8Encode(code, buffer[len..]) //
            catch std.debug.panic("illegal unicode: {}", .{code});
    }
    return buffer[0..len];
}

pub fn format(buf: []u8, comptime fmt: String, args: anytype) []u8 {
    return std.fmt.bufPrint(buf, fmt, args) catch @panic("text too long");
}

pub fn nextIndex(str: []const u8, index: usize) usize {
    const next = std.unicode.utf8ByteSequenceLength(str[index]);
    return index + (next catch unreachable);
}
