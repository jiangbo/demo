const std = @import("std");
const ray = @import("raylib.zig");
const stage = @import("stage.zig");
const SequenceType = stage.SequenceType;
const SequenceData = stage.SequenceData;

pub const State = struct {
    current: Sequence,
    box: ray.Texture2D,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) State {
        return State{
            .current = Sequence{ .title = Title.init() },
            .box = ray.LoadTexture("data/image/box.dds"),
            .allocator = allocator,
        };
    }

    pub fn update(self: *State) void {
        const sequence = self.current.update() orelse return;

        const old = self.current;
        self.current = switch (sequence) {
            .title => .{ .title = Title.init() },
            .select => .{ .select = Select.init() },
            .stage => |level| label: {
                const s = stage.init(self.allocator, level, self.box);
                break :label .{ .stage = s orelse return };
            },
        };
        old.deinit();
    }

    pub fn draw(self: State) void {
        self.current.draw();
    }

    pub fn deinit(self: State) void {
        self.current.deinit();
        ray.UnloadTexture(self.box);
    }
};

pub const Sequence = union(SequenceType) {
    title: Title,
    select: Select,
    stage: stage.Stage,

    fn update(self: *Sequence) ?SequenceData {
        return switch (self.*) {
            inline else => |*case| case.update(),
        };
    }

    fn draw(self: Sequence) void {
        ray.BeginDrawing();
        defer ray.EndDrawing();
        defer ray.DrawFPS(235, 10);
        ray.ClearBackground(ray.WHITE);

        switch (self) {
            inline else => |sequence| sequence.draw(),
        }
    }

    fn deinit(self: Sequence) void {
        switch (self) {
            inline else => |case| case.deinit(),
        }
    }
};

const Title = struct {
    texture: ray.Texture2D,

    fn init() Title {
        return Title{ .texture = ray.LoadTexture("data/image/title.dds") };
    }

    fn update(_: Title) ?SequenceData {
        return if (ray.IsKeyPressed(ray.KEY_SPACE)) .select else null;
    }

    fn draw(self: Title) void {
        ray.DrawTexture(self.texture, 0, 0, ray.WHITE);
    }

    fn deinit(self: Title) void {
        ray.UnloadTexture(self.texture);
    }
};

const Select = struct {
    texture: ray.Texture2D,

    fn init() Select {
        return Select{ .texture = ray.LoadTexture("data/image/select.dds") };
    }

    fn update(_: Select) ?SequenceData {
        const char = ray.GetCharPressed();
        return if (char >= '1' and char <= '9')
            .{ .stage = @intCast(char - '1' + 1) }
        else
            null;
    }

    fn draw(self: Select) void {
        ray.DrawTexture(self.texture, 0, 0, ray.WHITE);
    }

    fn deinit(self: Select) void {
        ray.UnloadTexture(self.texture);
    }
};
