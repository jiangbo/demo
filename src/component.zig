const std = @import("std");
const engine = @import("engine.zig");

pub const Player = struct {};

pub const Position = struct {
    x: usize,
    y: usize,

    pub fn fromVec(vec: engine.Vec) Position {
        return Position{ .x = vec.x, .y = vec.y };
    }

    pub fn toVec(self: Position) engine.Vec {
        return engine.Vec{ .x = self.x, .y = self.y };
    }
};

pub const Sprite = struct {
    sheet: engine.SpriteSheet,
    index: usize = 0,
};
