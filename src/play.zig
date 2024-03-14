const std = @import("std");
const engine = @import("engine.zig");
const map = @import("map.zig");

pub fn init(allocator: std.mem.Allocator, level: usize, box: engine.Texture) ?Play {
    const m = map.Map.init(allocator, level) catch |err| {
        std.log.err("init stage error: {}", .{err});
        return null;
    } orelse return null;
    return .{ .map = m, .box = box };
}

pub const Play = struct {
    map: map.Map,
    box: engine.Texture,

    pub fn update(_: *Play) ?@import("popup.zig").PopupType {
        if (engine.isPressed(engine.Key.x)) return .over;

        return null;
    }

    pub fn draw(self: Play) void {
        for (0..self.map.height) |y| {
            for (0..self.map.width) |x| {
                const item = self.map.data[y * self.map.width + x];
                if (item != map.MapItem.WALL) {
                    self.drawCell(x, y, if (item.hasGoal()) .GOAL else .SPACE);
                }
                if (item != .SPACE) self.drawCell(x, y, item);
            }
        }
    }

    fn drawCell(play: Play, x: usize, y: usize, item: map.MapItem) void {
        var source = engine.Rectangle{ .width = 32, .height = 32 };
        source.x = item.toImageIndex() * source.width;
        const position = .{ .x = x * source.width, .y = y * source.height };
        play.box.drawRectangle(source, position);
    }

    pub fn deinit(self: Play) void {
        self.map.deinit();
    }
};
