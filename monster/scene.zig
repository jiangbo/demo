const std = @import("std");
const zhu = @import("zhu");

const map = @import("map.zig");

pub fn init() void {
    map.init();
}

pub fn deinit() void {
    map.deinit();
}

pub fn update(delta: f32) void {
    map.update(delta);
}

pub fn draw() void {
    map.draw();
    for (map.startPaths) |start| {
        if (start == 0) break;

        var prev = map.paths.get(start).?;
        while (prev.next != 0) {
            const next = map.paths.get(prev.next).?;
            zhu.batch.drawLine(prev.point, next.point, .{
                .color = .red,
                .width = 4,
            });
            prev = next;
        }
    }
}
