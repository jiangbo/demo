const std = @import("std");
const file = @import("file.zig");
const ray = @import("raylib.zig");
const pop = @import("popup.zig");
const play = @import("play.zig");

pub const SequenceType = enum { title, select, stage };
pub const SequenceData = union(SequenceType) {
    title: void,
    select: void,
    stage: usize,
};
const PopupType = pop.PopupType;

pub fn init(allocator: std.mem.Allocator, level: usize, box: file.Texture) ?Stage {
    return Stage{
        .level = level,
        .current = play.init(allocator, level, box) orelse return null,
        .popup = .{ .loading = pop.Loading.init() },
    };
}

pub const Stage = struct {
    level: usize,
    current: play.Play,
    popup: ?pop.Popup = null,

    pub fn update(self: *Stage) ?SequenceData {
        if (self.popup) |*option| {
            const popup = option.update() orelse return null;
            switch (popup) {
                .title => return .title,
                .select => return .select,
                .reset => return .{ .stage = self.level },
                .quit => self.popup = null,
                .clear, .menu, .loading => unreachable,
            }
            return null;
        }

        const sequence = self.current.update() orelse return null;
        switch (sequence) {
            .clear => self.popup = .{ .clear = pop.Clear.init() },
            .menu => self.popup = .{ .menu = pop.Menu.init() },
            .title, .select, .reset, .quit, .loading => unreachable,
        }

        return null;
    }

    pub fn draw(self: Stage) void {
        self.current.draw();
        if (self.popup) |popup| popup.draw();
    }

    pub fn deinit(self: Stage) void {
        if (self.popup) |popup| popup.deinit();
        self.current.deinit();
    }
};
