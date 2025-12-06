const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const batch = @import("batch.zig");
const font = @import("font.zig");

const Font = font.Font;
const Glyph = font.Glyph;

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

pub fn drawNumber(number: anytype, position: math.Vector) void {
    drawColorNumber(number, position, .one);
}

pub fn drawColorNumber(number: anytype, pos: math.Vector, color: Color) void {
    var textBuffer: [15]u8 = undefined;
    const text = std.fmt.bufPrint(textBuffer[0..], "{d}", .{number});
    const t = text catch unreachable;
    drawOption(t, .{ .position = pos, .color = color });
}

pub fn drawText(text: []const u8, position: math.Vector) void {
    drawOption(text, .{ .position = position });
}

const Color = math.Vector4;
pub fn drawColorText(text: []const u8, pos: math.Vector, color: Color) void {
    drawOption(text, .{ .position = pos, .color = color });
}

pub const Option = struct {
    size: ?f32 = null,
    position: math.Vector,
    color: math.Vector4 = .one,
    width: f32 = std.math.floatMax(f32),
};
const Utf8View = std.unicode.Utf8View;
pub fn drawOption(text: []const u8, options: Option) void {
    var iterator = Utf8View.initUnchecked(text).iterator();

    const size = options.size orelse textSize;
    const height = zon.metrics.lineHeight * size;
    const offsetY = -zon.metrics.ascender * size;
    var pos = options.position.addY(offsetY);

    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') {
            pos = .init(options.position.x, pos.y + height);
            continue;
        }
        if (pos.x > options.width) {
            pos = .init(options.position.x, pos.y + height);
        }
        const char = searchGlyph(code);
        count += 1;

        const target = char.planeBounds.toArea();
        const tex = texture.mapTexture(char.atlasBounds.toArea());
        batch.drawOption(tex, pos.add(target.min.scale(size)), .{
            .size = target.size.scale(size),
            .color = options.color,
        });
        pos = pos.addX(char.advance * size);
    }
}

pub fn computeTextWidth(text: []const u8) f32 {
    var iterator = Utf8View.initUnchecked(text).iterator();

    var width: f32 = 0;
    while (iterator.nextCodepoint()) |code| {
        width += searchGlyph(code).advance * textSize;
    }
    return width;
}
