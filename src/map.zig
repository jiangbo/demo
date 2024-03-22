const std = @import("std");
const engine = @import("engine.zig");
const core = @import("map/core.zig");
const world = @import("map/world.zig");
const ai = @import("map/ai.zig");

const Player = @import("map/player.zig").Player;

pub fn init() void {
    core.init();
}

pub fn deinit() void {
    core.deinit();
}

const stageConfig = [_]core.StageConfig{
    .{ .enemy = 2, .brickRate = 90, .power = 4, .bomb = 6 },
    .{ .enemy = 3, .brickRate = 80, .power = 1, .bomb = 0 },
    .{ .enemy = 6, .brickRate = 30, .power = 1, .bomb = 1 },
};

pub const Map = struct {
    world: world.World,

    pub fn init(level: usize) ?Map {
        _ = level;
        var initWorld = world.World.init(stageConfig[0]) orelse return null;
        initWorld.players[0] = Player.genPlayer(1, 1);
        defer ai.init(initWorld);
        return Map{ .world = initWorld };
    }

    pub fn update(self: *Map) void {
        const pos = self.player1().getCell();
        const mapUnit = self.world.indexRef(pos.x, pos.y);

        if (mapUnit.contains(.item)) {
            mapUnit.remove(.item);
            self.player1().maxBombNumber += 1;
        }

        if (mapUnit.contains(.power)) {
            self.player1().maxBombLength += 1;
            mapUnit.remove(.power);
        }

        self.world.update();
    }

    pub fn player1(self: Map) *Player {
        return self.world.player1();
    }

    pub fn control(self: Map, speed: usize, direction: core.Direction) void {
        if (direction == .west) {
            var p1 = self.world.players[0];
            p1.x -|= speed;
            const cell = p1.getCell();
            if (!self.world.isCollisionX(p1, cell.x -| 1, cell.y))
                self.world.players[0].x -|= speed;
        }

        if (direction == .east) {
            var p1 = self.world.players[0];
            p1.x += speed;
            const cell = p1.getCell();
            if (!self.world.isCollisionX(p1, cell.x + 1, cell.y))
                self.world.players[0].x +|= speed;
        }

        if (direction == .north) {
            var p1 = self.world.players[0];
            p1.y -|= speed;
            const cell = p1.getCell();
            if (!self.world.isCollisionY(p1, cell.x, cell.y -| 1))
                self.world.players[0].y -|= speed;
        }

        if (direction == .south) {
            var p1 = self.world.players[0];
            p1.y += speed;
            const cell = p1.getCell();
            if (!self.world.isCollisionY(p1, cell.x, cell.y + 1))
                self.world.players[0].y += speed;
        }
    }

    pub fn setBomb(self: *Map, player: *Player) void {
        if (player.bombNumber >= player.maxBombNumber) return;

        const pos = player.getCell();
        const cell = self.world.indexRef(pos.x, pos.y);
        if (!cell.contains(.wall) and !cell.contains(.brick)) {
            cell.insertTimedType(.bomb, engine.time());
            player.bombNumber += 1;
        }
    }

    pub fn draw(self: Map) void {
        self.world.draw();
    }

    pub fn deinit(self: *Map) void {
        ai.deinit();
        self.world.deinit();
    }
};
