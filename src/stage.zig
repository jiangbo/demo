const std = @import("std");
const map = @import("map.zig");
const file = @import("file.zig");
const ray = @import("raylib.zig");
const play = @import("play.zig");

pub const SequenceType = enum { title, select, stage };
pub const SequenceData = union(SequenceType) {
    title: void,
    select: void,
    stage: usize,
};
const Allocator = std.mem.Allocator;
const PlayingType = play.PlayingType;

pub const Stage = struct {
    map: map.Map,
    box: file.Texture,
    current: Sequence,

    pub fn update(self: *Stage) ?SequenceData {
        const sequence = self.current.update() orelse return null;

        const old = self.current;
        defer old.deinit();

        self.current = switch (sequence) {
            .loading => .{ .loading = Loading.init() },
            .play => .{ .play = play.init(self.map, self.box) },
            .title => return .title,
        };

        return null;
    }

    pub fn draw(self: Stage) void {
        self.current.draw();
    }

    pub fn deinit(self: Stage) void {
        self.map.deinit();
    }
};

const Sequence = union(PlayingType) {
    loading: Loading,
    play: play.Play,
    title: void,

    fn update(self: *Sequence) ?PlayingType {
        return switch (self.*) {
            .title => unreachable,
            inline else => |*case| case.update(),
        };
    }

    fn draw(self: Sequence) void {
        switch (self) {
            .title => unreachable,
            inline else => |sequence| sequence.draw(),
        }
    }

    fn deinit(self: Sequence) void {
        switch (self) {
            .loading => |sequence| sequence.deinit(),
            else => {},
        }
    }
};

const Loading = struct {
    texture: file.Texture,
    time: f64,

    fn init() Loading {
        return Loading{
            .texture = file.loadTexture("loading.dds"),
            .time = ray.GetTime(),
        };
    }

    fn update(self: Loading) ?PlayingType {
        return if ((ray.GetTime() - self.time) > 1) return .play else null;
    }

    fn draw(self: Loading) void {
        ray.DrawTexture(self.texture.texture, 0, 0, ray.WHITE);
    }

    fn deinit(self: Loading) void {
        self.texture.unload();
    }
};

pub fn init(allocator: Allocator, level: usize, box: file.Texture) ?Stage {
    const m = map.Map.init(allocator, level) catch |err| {
        std.log.err("init stage error: {}", .{err});
        return null;
    } orelse return null;
    return Stage{ .map = m, .box = box, .current = .{ .loading = Loading.init() } };
}
