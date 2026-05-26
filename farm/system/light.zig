const std = @import("std");
const zhu = @import("zhu");

const context = @import("../context.zig");

const Keyframe = struct {
    hour: f32,
    color: zhu.Color,
};

// 屏幕覆盖色关键帧：只做可见昼夜色调，不模拟真实光照。
const keyframes = [_]Keyframe{
    .{ .hour = 4, .color = .rgba(0.04, 0.06, 0.16, 0.42) },
    .{ .hour = 6, .color = .rgba(0.68, 0.30, 0.10, 0.18) },
    .{ .hour = 9, .color = .rgba(0, 0, 0, 0) },
    .{ .hour = 14, .color = .rgba(0, 0, 0, 0) },
    .{ .hour = 18, .color = .rgba(0.80, 0.32, 0.08, 0.22) },
    .{ .hour = 22, .color = .rgba(0.03, 0.05, 0.18, 0.48) },
    .{ .hour = 28, .color = .rgba(0.04, 0.06, 0.16, 0.42) },
};

pub fn draw() void {
    const hour = @as(f32, @floatFromInt(context.time.hour)) +
        context.time.minute / 60;
    const overlay = overlayAt(hour);
    if (overlay.a <= 0.001) return;

    zhu.batch.drawRect(.init(.zero, zhu.camera.size), .{
        .color = overlay,
    });
}

pub fn overlayAt(hour: f32) zhu.Color {
    const sampleHour = if (hour < 4) hour + 24 else hour;

    var i: usize = 0;
    while (i + 1 < keyframes.len) : (i += 1) {
        const left = keyframes[i];
        const right = keyframes[i + 1];
        if (sampleHour >= left.hour and sampleHour < right.hour) {
            const t = smoothStep((sampleHour - left.hour) /
                (right.hour - left.hour));
            return left.color.mix(right.color, t);
        }
    }

    return keyframes[keyframes.len - 1].color;
}

fn smoothStep(value: f32) f32 {
    const t = std.math.clamp(value, 0, 1);
    return t * t * (3 - 2 * t);
}

test "light overlay 正午不改变画面" {
    const color = overlayAt(12);
    try std.testing.expectApproxEqAbs(@as(f32, 0), color.a, 0.001);
}

test "light overlay 深夜比白天更明显" {
    const night = overlayAt(23);
    const noon = overlayAt(12);

    try std.testing.expect(night.a > noon.a);
    try std.testing.expect(night.b > night.r);
}

test "light overlay 黄昏偏暖" {
    const color = overlayAt(18);

    try std.testing.expect(color.a > 0.1);
    try std.testing.expect(color.r > color.b);
}

test "light overlay 黎明偏暖" {
    const color = overlayAt(6);

    try std.testing.expect(color.a > 0.1);
    try std.testing.expect(color.r > color.b);
}

test "light overlay 支持跨午夜插值" {
    const night = overlayAt(22);
    const middle = overlayAt(1);
    const early = overlayAt(4);

    try std.testing.expect(night.a > middle.a);
    try std.testing.expect(middle.a > early.a);
}
