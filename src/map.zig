const std = @import("std");
const engine = @import("engine.zig");
const core = @import("map/core.zig");
const world = @import("map/world.zig");

const Player = @import("map/player.zig").Player;
pub const Direction = @import("map/player.zig").Direction;

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

var maxBombNumber: usize = 1;

pub const Map = struct {
    world: world.World,

    pub fn init(level: usize) ?Map {
        _ = level;
        var initWorld = world.World.init(stageConfig[0]) orelse return null;
        initWorld.players[0] = Player.genPlayer(1, 1);
        return Map{ .world = initWorld };
    }

    pub fn update(self: *Map) void {
        self.world.update();
    }

    pub fn player1(self: Map) *Player {
        return &self.world.players[0];
    }

    pub fn control(self: Map, speed: usize, direction: Direction) void {
        if (direction == .west) {
            var p1 = self.world.players[0];
            p1.x -|= speed;
            if (!self.isCollisionX(p1, p1.getCell().x -| 1, p1.getCell().y))
                self.world.players[0].x -|= speed;
        }

        if (direction == .east) {
            var p1 = self.world.players[0];
            p1.x += speed;
            if (!self.isCollisionX(p1, p1.getCell().x + 1, p1.getCell().y))
                self.world.players[0].x +|= speed;
        }

        if (direction == .north) {
            var p1 = self.world.players[0];
            p1.y -|= speed;
            if (!self.isCollisionY(p1, p1.getCell().x, p1.getCell().y -| 1))
                self.world.players[0].y -|= speed;
        }

        if (direction == .south) {
            var p1 = self.world.players[0];
            p1.y += speed;
            if (!self.isCollisionY(p1, p1.getCell().x, p1.getCell().y + 1))
                self.world.players[0].y += speed;
        }
    }

    fn isCollisionX(self: Map, player: Player, x: usize, y: usize) bool {
        const rect = player.toCollisionRec();
        for (0..3) |i| {
            if (self.world.isCollision(x, y + i -| 1, rect)) return true;
        } else return false;
    }

    fn isCollisionY(self: Map, player: Player, x: usize, y: usize) bool {
        const rect = player.toCollisionRec();
        for (0..3) |i| {
            if (self.world.isCollision(x + i -| 1, y, rect)) return true;
        } else return false;
    }

    pub fn setBomb(self: *Map, player: *Player) void {
        if (player.bombNumber >= maxBombNumber) return;

        const pos = player.getCell();
        const cell = self.world.indexRef(pos.x, pos.y);
        if (!cell.contains(.wall) and !cell.contains(.brick)) {
            cell.insertTimedType(.bomb, engine.time());
        }
    }

    pub fn draw(self: Map) void {
        self.world.draw();
    }

    pub fn deinit(self: *Map) void {
        self.world.deinit();
    }
};
