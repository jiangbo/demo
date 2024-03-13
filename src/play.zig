const std = @import("std");
const map = @import("map.zig");
const file = @import("file.zig");
const ray = @import("raylib.zig");

pub const PlayingType = enum { loading, play, title };

pub fn init(m: map.Map, box: file.Texture) Play {
    return .{ .map = m, .box = box };
}

pub const Play = struct {
    map: map.Map,
    box: file.Texture,

    pub fn update(self: *Play) ?PlayingType {

        // 操作角色移动的距离
        const delta: isize = switch (ray.GetKeyPressed()) {
            ray.KEY_W, ray.KEY_UP => -@as(isize, @intCast(self.map.width)),
            ray.KEY_S, ray.KEY_DOWN => @as(isize, @intCast(self.map.width)),
            ray.KEY_D, ray.KEY_RIGHT => 1,
            ray.KEY_A, ray.KEY_LEFT => -1,
            else => return null,
        };

        const currentIndex = self.map.playerIndex();
        const index = @as(isize, @intCast(currentIndex)) + delta;
        if (index < 0 or index > self.map.size()) return null;

        // 角色欲前往的目的地
        const destIndex = @as(usize, @intCast(index));
        self.updatePlayer(currentIndex, destIndex, delta);

        return if (self.map.hasCleared()) .title else null;
    }

    fn updatePlayer(play: *Play, current: usize, dest: usize, delta: isize) void {
        var state = play.map.data;
        if (state[dest] == .SPACE or state[dest] == .GOAL) {
            // 如果是空地或者目标地，则可以移动
            state[dest] = if (state[dest] == .GOAL) .MAN_ON_GOAL else .MAN;
            state[current] = if (state[current] == .MAN_ON_GOAL) .GOAL else .SPACE;
        } else if (state[dest] == .BLOCK or state[dest] == .BLOCK_ON_GOAL) {
            //  如果是箱子或者目的地上的箱子，需要考虑该方向上的第二个位置
            const index = @as(isize, @intCast(dest)) + delta;
            if (index < 0 or index > play.map.size()) return;

            const next = @as(usize, @intCast(index));
            if (state[next] == .SPACE or state[next] == .GOAL) {
                state[next] = if (state[next] == .GOAL) .BLOCK_ON_GOAL else .BLOCK;
                state[dest] = if (state[dest] == .BLOCK_ON_GOAL) .MAN_ON_GOAL else .MAN;
                state[current] = if (state[current] == .MAN_ON_GOAL) .GOAL else .SPACE;
            }
        }
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
        var source = ray.Rectangle{ .width = 32, .height = 32 };
        source.x = item.toImageIndex() * source.width;
        const dest = ray.Rectangle{
            .x = @as(f32, @floatFromInt(x)) * source.width,
            .y = @as(f32, @floatFromInt(y)) * source.height,
            .width = source.width,
            .height = source.height,
        };

        ray.DrawTexturePro(play.box.texture, source, dest, .{}, 0, ray.WHITE);
    }
};
