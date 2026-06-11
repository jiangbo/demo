const std = @import("std");

const audio = @import("audio.zig");
const batch = @import("batch.zig");
const camera = @import("camera.zig");
const graphics = @import("graphics.zig");
const input = @import("input.zig");
const text = @import("text.zig");
const window = @import("window.zig");

const Color = graphics.Color;
const Vector2 = @import("math.zig").Vector2;
const Rect = @import("math.zig").Rect;

const panelColor = Color.rgba(0.07, 0.09, 0.11, 0.74);
const borderColor = Color.rgba(0.45, 0.55, 0.62, 0.38);
const textColor = Color.rgba(0.86, 0.89, 0.90, 0.96);
const basePadding = Vector2.xy(10, 9);
const basePosition = Vector2.xy(10, 10);
const labelWidth: usize = 6;
const leftWidth: usize = 14;
const rightWidth: usize = 18;

var fps: u32 = 0;
var fpsTime: u64 = 0;
var fpsFrameCount: u64 = 0;
var lastTextCount: usize = 0;

pub fn draw() void {
    const now = window.relativeTime();
    const currentFrame = window.frameCount();
    if (fpsTime == 0) {
        fpsTime = now;
        fpsFrameCount = currentFrame;
    } else if (now > fpsTime + std.time.ns_per_s) {
        fps = @intCast(currentFrame - fpsFrameCount);
        fpsTime = now;
        fpsFrameCount = currentFrame;
    }

    const frameMs = window.frameDuration() * 1000;

    var buffer: [1000]u8 = undefined;
    const frameStats = graphics.queryFrameStats();
    const gpuBytes = frameStats.size_append_buffer +
        frameStats.size_update_buffer;
    var writer = std.Io.Writer.fixed(&buffer);
    writeFormatLine(&writer, "后端", "{s}", .{
        @tagName(graphics.queryBackend()),
    }, "帧率 {}", .{fps});
    // used 需要主循环额外记录耗时，这里先按约定显示 0。
    writeFormatLine(&writer, "帧时", "{d:.2}ms", .{
        frameMs,
    }, "用时 {d:.2}ms", .{@as(f32, 0)});
    writeFormatLine(&writer, "内存", "{}", .{
        window.countingAllocator.used,
    }, "显存 {}", .{gpuBytes});
    writeFormatLine(&writer, "批次", "命令 {}", .{
        batch.commands.items.len,
    }, "绘制 {}", .{frameStats.num_draw});
    writeFormatLine(&writer, "绘制", "精灵 {}", .{
        batch.vertices.items.len,
    }, "文字 {}", .{graphics.stats.text + lastTextCount});
    writeFormatLine(&writer, "鼠标", "{d:.1}, {d:.1}", .{
        input.mouse.raw.x,
        input.mouse.raw.y,
    }, "{d:.1}, {d:.1}", .{ window.mouse.x, window.mouse.y });
    writeFormatLine(&writer, "相机", "{d:.1}, {d:.1}", .{
        camera.position.x,
        camera.position.y,
    }, "{d:.2}, {d:.2}", .{ camera.scale.x, camera.scale.y });
    // 图片/文件/音效/音乐数量目前没有直接内部入口，先显示 0。
    writeFormatLine(&writer, "资源", "图片 {}", .{@as(usize, 0)}, "文件 {}", .{
        @as(usize, 0),
    });
    writeFormatLine(&writer, "音频", "音乐 {}", .{@as(usize, 0)}, "音效 {}", .{
        @as(usize, 0),
    });
    writeFormatLine(&writer, "音量", "音乐 {d:.0}%", .{
        audio.musicVolume.load(.acquire) * 100,
    }, "音效 {d:.0}%", .{audio.soundVolume.load(.acquire) * 100});
    const debugText = buffer[0 .. writer.end - 1];

    // 调试面板固定在窗口坐标，绘制后还原，不改变正常相机状态。
    const previousMode = camera.mode;
    camera.mode = .window;
    defer camera.mode = previousMode;

    const scale = debugTextScale(debugText);
    const padding = basePadding.scale(scale.x);
    const position = basePosition.scale(scale.x);
    const textOption = text.Option{
        .color = textColor,
        .scale = scale,
    };
    const textSize = text.measure(debugText, textOption);
    const panel = Rect.init(position, textSize.add(padding.scale(2)));

    batch.drawRect(panel, .{ .color = panelColor });
    batch.drawRectBorder(panel, scale.x, borderColor);

    const contentPosition = position.add(padding);
    text.drawString(debugText, contentPosition, textOption);

    lastTextCount = text.computeTextCount(debugText);
}

fn debugTextScale(debugText: text.String) Vector2 {
    const baseOption = text.Option{};
    const baseSize = text.measure(debugText, baseOption)
        .add(basePadding.scale(2));
    const targetWidth = window.size.x * 0.45;
    const maxHeight = window.size.y * 0.75;

    const widthScale = targetWidth / baseSize.x;
    const heightScale = maxHeight / baseSize.y;
    const rawScale = @min(widthScale, heightScale);

    // 按半档缩放，避免调试面板盖住主要画面。
    const stepped = @round(std.math.clamp(rawScale, 0.5, 1.5) * 2) / 2;
    return .square(stepped);
}

fn writeFormatLine(
    writer: *std.Io.Writer,
    label: []const u8,
    comptime leftFormat: []const u8,
    leftArgs: anytype,
    comptime rightFormat: []const u8,
    rightArgs: anytype,
) void {
    var leftBuffer: [80]u8 = undefined;
    var rightBuffer: [80]u8 = undefined;
    const left = text.format(&leftBuffer, leftFormat, leftArgs);
    const right = text.format(&rightBuffer, rightFormat, rightArgs);
    appendCell(writer, label, labelWidth);
    appendCell(writer, left, leftWidth);
    writeAll(writer, "  ");
    appendCell(writer, right, rightWidth);
    writeAll(writer, "\n");
}

fn appendCell(writer: *std.Io.Writer, value: []const u8, width: usize) void {
    writeAll(writer, value);
    const count = displayWidth(value);
    if (count >= width) return;
    for (0..width - count) |_| writeAll(writer, " ");
}

fn displayWidth(value: []const u8) usize {
    var result: usize = 0;
    var iterator = std.unicode.Utf8View.initUnchecked(value).iterator();
    while (iterator.nextCodepoint()) |code| {
        result += if (code < 128) 1 else 2;
    }
    return result;
}

fn writeAll(writer: *std.Io.Writer, value: []const u8) void {
    writer.writeAll(value) catch @panic("debug text too long");
}
