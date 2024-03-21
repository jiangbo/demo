const std = @import("std");
const engine = @import("engine.zig");
const core = @import("map/core.zig");
const background = @import("map/background.zig");
const foreground = @import("map/foreground.zig");

pub fn init() void {
    core.init();
}

pub fn deinit() void {
    core.deinit();
}

const stageConfig = [_]core.StageConfig{
    .{ .enemy = 2, .brickRate = 90, .power = 4, .bomb = 6 },
    .{ .enemy = 3, .brickRate = 80, .power = 1, .bomb = 0 },
    .{ .enemy = 6, .brickRate = 30, .power = 0, .bomb = 1 },
};

fn genItem(map: *background.BackgroundMap, config: core.StageConfig) void {
    var bricks: [map.len]engine.Vector = undefined;
    bricks.len = 0;

    for (0..map.height) |y| {
        for (0..map.width) |x| {
            if (map.data[x + y * map.width].contains(.brick)) {
                bricks[bricks.len] = .{ .x = x, .y = y };
                bricks.len += 1;
            }
        }
    }

    for (0..config.bomb + config.power) |i| {
        const swapped = engine.randomW(i, bricks.len);
        const tmp = bricks[i];
        bricks[i] = bricks[swapped];
        bricks[swapped] = tmp;
        const item: core.BackMapType = if (i < config.power) .power else .item;
        map.data[bricks[i].x + bricks[i].y * map.width].insert(item);
    }
}

// fn generatePlayer(self: ForegroundMap, floors: []usize, cfg: core.StageConfig) void {
//     for (0..cfg.enemy) |i| {
//         const swapped = engine.randomW(i, floors.len);
//         const tmp = floors[i];
//         floors[i] = floors[swapped];
//         floors[swapped] = tmp;
//         self.roles[1 + i] = .{
//             .x = (floors[i] >> 16 & 0xFFFF) * tileMap.unit * speedUnit,
//             .y = (floors[i] & 0xFFFF) * tileMap.unit * speedUnit,
//         };
//     }
// }

pub const World = struct {
    fg: foreground.ForegroundMap,
    bg: background.BackgroundMap,

    pub fn init(level: usize) ?World {
        _ = level;
        const config = stageConfig[0];

        _ = background.BackgroundMap.init(config);

        return World{};
    }

    pub fn update(self: *World) void {
        _ = self;
    }

    pub fn draw(self: World) void {
        self.bg.draw();
        self.fg.draw();
    }

    pub fn deinit(self: *World) void {
        self.fg.deinit();
    }
};
