const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const batch = @import("batch.zig");
const font = @import("font.zig");
const window = @import("window.zig");

const Font = font.Font;
const Glyph = font.Glyph;
const Vector = math.Vector2;

var zon: font.Font = undefined;
var texture: gpu.Texture = undefined;
var textSize: f32 = 18;
pub var count: u32 = 0;
var invalidUnicode: u32 = 0x25A0;
var invalidIndex: usize = 0;

pub fn init(fontZon: Font, fontTexture: gpu.Texture, size: f32) void {
    zon = fontZon;
    texture = fontTexture;
    invalidIndex = binarySearch(invalidUnicode) orelse @panic("no invalid char");
    textSize = size;
}

fn binarySearch(unicode: u32) ?usize {
    return std.sort.binarySearch(Glyph, zon.glyphs, unicode, struct {
        fn compare(a: u32, b: Glyph) std.math.Order {
            return std.math.order(a, b.unicode);
        }
    }.compare);
}

fn searchGlyph(code: u32) *const Glyph {
    return &zon.glyphs[binarySearch(code) orelse invalidIndex];
}

pub fn drawNumber(number: anytype, position: Vector) void {
    drawNumberColor(number, position, .one);
}

pub fn drawNumberColor(number: anytype, pos: Vector, color: Color) void {
    var textBuffer: [15]u8 = undefined;
    const text = format(&textBuffer, "{d}", .{number});
    drawColor(text, pos, color);
}

pub fn draw(text: []const u8, position: math.Vector) void {
    drawOption(text, position, .{});
}

pub fn drawCenter(text: []const u8, y: f32, option: Option) void {
    const width = computeTextWidthOption(text, option);
    const x = (window.logicSize.x - width) / 2;
    drawOption(text, .init(x, window.logicSize.y * y), option);
}

pub fn drawFmt(fmt: []const u8, pos: Vector, args: anytype) void {
    var buffer: [1024]u8 = undefined;
    draw(format(&buffer, fmt, args), pos);
}

const Color = math.Vector4;
pub fn drawColor(text: []const u8, pos: Vector, color: Color) void {
    drawOption(text, pos, .{ .color = color });
}

pub const Option = struct {
    size: ?f32 = null, // 文字的大小，没有则使用默认值
    color: math.Vector4 = .one, // 文字的颜色
    maxWidth: f32 = std.math.floatMax(f32), // 最大宽度，超过换行
    spacing: f32 = 0, // 文字间的间距
};
const Utf8View = std.unicode.Utf8View;
pub fn drawOption(text: []const u8, position: Vector, option: Option) void {
    var iterator = Utf8View.initUnchecked(text).iterator();

    const size = option.size orelse textSize;
    const height = zon.metrics.lineHeight * size;
    const offsetY = -zon.metrics.ascender * size;
    var pos = position.addY(offsetY);

    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') {
            pos = .init(position.x, pos.y + height);
            continue;
        }
        if (pos.x > option.maxWidth) {
            pos = .init(position.x, pos.y + height);
        }
        const char = searchGlyph(code);
        count += 1;

        const target = char.planeBounds.toArea();
        const tex = texture.mapTexture(char.atlasBounds.toArea());
        batch.drawOption(tex, pos.add(target.min.scale(size)), .{
            .size = target.size.scale(size),
            .color = option.color,
        });
        pos = pos.addX(char.advance * size + option.spacing);
    }
}

pub fn computeTextWidth(text: []const u8) f32 {
    return computeTextWidthOption(text, .{});
}

pub fn computeTextWidthOption(text: []const u8, option: Option) f32 {
    var width: f32 = 0;
    const sz = option.size orelse textSize; // 提供则获取，没有则获取默认值
    var iterator = Utf8View.initUnchecked(text).iterator();
    while (iterator.nextCodepoint()) |code| {
        width += searchGlyph(code).advance * sz + option.spacing;
    }
    return width - option.spacing;
}

fn format(buf: []u8, fmt: []const u8, args: anytype) []u8 {
    return std.fmt.bufPrint(buf, fmt, args) catch @panic("text too long");
}
