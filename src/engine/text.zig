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

var invalidIndex: usize = 0;

pub var font: Font = undefined;
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
    offset: Vector2 = .zero, // 文字位置偏移
    scale: Vector2 = .one, // 基于默认字号的缩放
    color: graphics.Color = .white, // 文字的颜色
    max: f32 = std.math.floatMax(f32), // 最大宽度，超过换行
    spacing: f32 = 0, // 文字间的间距
    anchor: ?Vector2 = null, // 锚点

    pub fn with(
        self: Option,
        comptime field: std.meta.FieldEnum(Option),
        value: @FieldType(Option, @tagName(field)),
    ) Option {
        var result = self;
        @field(result, @tagName(field)) = value;
        return result;
    }
};

pub const Line = struct { text: String, option: Option = .{} };
pub const Lines = []const Line;

pub fn drawNumber(number: anytype, pos: Vector2, option: Option) void {
    var textBuffer: [15]u8 = undefined;
    const string = format(&textBuffer, "{d}", .{number});
    draw(string, pos, option);
}

// zig fmt: off
pub fn drawFmt(comptime fmt: String, args: anytype, pos: Vector2,
    option: Option) void {
// zig fmt: on
    var buffer: [1024]u8 = undefined;
    draw(format(&buffer, fmt, args), pos, option);
}

const Utf8View = std.unicode.Utf8View;
pub fn draw(text: String, position: Vector2, option: Option) void {
    _ = drawSize(text, position, option);
}

pub fn drawSize(text: String, position: Vector2, option: Option) Vector2 {
    if (text.len == 0) return .zero;
    var pos = position;
    if (option.anchor) |anchor| {
        pos = pos.sub(measure(text, option).mul(anchor));
    }
    return layout(text, pos, option, true);
}

fn layout(
    text: String,
    position: Vector2,
    option: Option,
    comptime render: bool,
) Vector2 {
    const scale = option.scale.scale(fontScale);
    const height = font.lineHeight * scale.y;
    var pos = position.add(option.offset);

    var width: f32, var line: f32 = .{ 0, 1 };
    var maxWidth: f32, const startX = .{ 0, pos.x };
    var iterator = Utf8View.initUnchecked(text).iterator();
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') {
            width, line = .{ 0, line + 1 };
            pos = .xy(startX, pos.y + height);
            continue;
        }

        const advance = charAdvance(code, scale.x);
        if (width > 0) {
            if (width + option.spacing + advance > option.max) {
                width, line = .{ 0, line + 1 };
                pos = .xy(startX, pos.y + height);
            } else {
                width += option.spacing;
                pos = pos.addX(option.spacing);
            }
        }
        width += advance;
        maxWidth = @max(maxWidth, width);

        if (render) {
            const char = searchChar(code);
            const image = fontImage.sub(char.area);
            batch.drawImage(image, pos.add(char.offset.mul(scale)), .{
                .size = char.area.size.mul(scale),
                .color = option.color,
            });
            graphics.stats.text += 1;
        }
        pos = .xy(startX + width, pos.y);
    }

    return .xy(maxWidth, line * height);
}

pub fn drawLines(lines: Lines, position: Vector2, spacing: f32) void {
    var y: f32 = 0;
    for (lines) |line| {
        const size = drawSize(line.text, position.addY(y), line.option);
        y += size.y + spacing;
    }
}

pub fn measure(text: String, option: Option) Vector2 {
    if (text.len == 0) return .zero;
    return layout(text, .zero, option.with(.anchor, null), false);
}

pub fn measureLines(lines: Lines, spacing: f32) Vector2 {
    var size: Vector2 = .zero;
    for (lines, 0..) |line, i| {
        const lineSize = measure(line.text, line.option);
        size.x = @max(size.x, lineSize.x);
        size.y += lineSize.y;
        if (i + 1 < lines.len) size.y += spacing;
    }
    return size;
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
