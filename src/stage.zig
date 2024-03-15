const std = @import("std");
const popup = @import("popup.zig");
const play = @import("play.zig");
const map = @import("map.zig");

pub const SequenceType = enum { title, select, stage };
pub const SequenceData = union(SequenceType) {
    title: void,
    select: void,
    stage: usize,
};

pub fn init(allocator: std.mem.Allocator, level: usize) ?Stage {
    const worldMap = map.WorldMap.init(allocator, level);
    const p = play.Gameplay{ .map = worldMap orelse return null };
    return Stage{ .level = level, .popup = popup.init(), .gameplay = p };
}

pub const Stage = struct {
    level: usize,
    gameplay: play.Gameplay,
    popup: ?popup.Popup = null,

    pub fn update(self: *Stage) ?SequenceData {
        if (self.popup) |*option| {
            const menu = option.update() orelse return null;
            defer option.deinit();
            switch (menu) {
                .title => return .title,
                .select => return .select,
                .reset => return .{ .stage = self.level },
                .next => return .{ .stage = self.level + 1 },
                .quit => self.popup = null,
            }
        }

        const popupType = self.gameplay.update() orelse return null;
        self.popup = popup.initWithType(popupType);
        return null;
    }

    pub fn draw(self: Stage) void {
        self.gameplay.draw();
        if (self.popup) |option| option.draw();
    }

    pub fn deinit(self: Stage) void {
        if (self.popup) |option| option.deinit();
        self.gameplay.deinit();
    }
};
