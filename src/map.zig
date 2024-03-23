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
    .{ .enemy = 2, .brickRate = 90, .power = 54, .bomb = 6 },
    .{ .enemy = 3, .brickRate = 80, .power = 1, .bomb = 0 },
    .{ .enemy = 6, .brickRate = 30, .power = 1, .bomb = 1 },
};

pub const Map = struct {
    world: world.World,
    twoPlayer: bool,
    pub fn init(twoPlayer: bool, level: usize) ?Map {
        const wd = world.World.init(twoPlayer, stageConfig[level]);
        var initWorld = wd orelse return null;
        initWorld.players[0] = Player.genPlayer(1, 1, .player1);
        if (twoPlayer) {
            const w, const h = .{ initWorld.width - 2, initWorld.height - 2 };
            initWorld.players[1] = Player.genPlayer(w, h, .player2);
        }
        defer ai.init(initWorld);
        return Map{ .world = initWorld, .twoPlayer = twoPlayer };
    }

    pub fn update(self: *Map) void {
        self.getItem(self.player1());
        self.getItem(self.player2());

        for (self.world.players) |*p| {
            if (!p.alive) continue;
            const enemyPos = p.getCell();
            const unit = self.world.index(enemyPos.x, enemyPos.y);
            if (unit.hasExplosion()) p.alive = false;

            if (p.type != .enemy) continue;
            if (enemyPos.isSame(self.player1().getCell()))
                self.player1().alive = false;
            if (enemyPos.isSame(self.player2().getCell()))
                self.player2().alive = false;
        }

        self.world.update();
    }

    fn getItem(self: *Map, player: *Player) void {
        const playerPos = player.getCell();
        const mapUnit = self.world.indexRef(playerPos.x, playerPos.y);

        if (mapUnit.contains(.item)) {
            mapUnit.remove(.item);
            player.maxBombNumber += 1;
        }

        if (mapUnit.contains(.power)) {
            player.maxBombLength += 1;
            mapUnit.remove(.power);
        }
    }

    pub fn player1(self: Map) *Player {
        return self.world.player1();
    }

    pub fn player2(self: Map) *Player {
        return self.world.player2();
    }

    pub fn alive(self: Map) bool {
        return self.player1().alive or self.player2().alive;
    }

    pub fn control(self: Map, player: *Player, speed: usize, direction: core.Direction) void {
        if (direction == .west) {
            var p = player.*;
            p.x -|= speed;
            const cell = p.getCell();
            if (!self.world.isCollisionX(p, cell.x -| 1, cell.y))
                player.x -|= speed;
        }

        if (direction == .east) {
            var p = player.*;
            p.x += speed;
            const cell = p.getCell();
            if (!self.world.isCollisionX(p, cell.x + 1, cell.y))
                player.x +|= speed;
        }

        if (direction == .north) {
            var p = player.*;
            p.y -|= speed;
            const cell = p.getCell();
            if (!self.world.isCollisionY(p, cell.x, cell.y -| 1))
                player.y -|= speed;
        }

        if (direction == .south) {
            var p = player.*;
            p.y += speed;
            const cell = p.getCell();
            if (!self.world.isCollisionY(p, cell.x, cell.y + 1))
                player.y += speed;
        }
    }

    pub fn setBomb(self: *Map, player: *Player) void {
        if (player.bombNumber >= player.maxBombNumber) return;

        const pos = player.getCell();
        const cell = self.world.indexRef(pos.x, pos.y);
        if (!cell.contains(.wall) and !cell.contains(.brick)) {
            cell.insertTimedType(.bomb, engine.time());
            cell.insert(player.type);
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
