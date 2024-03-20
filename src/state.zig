const std = @import("std");
const engine = @import("engine.zig");
const stage = @import("stage.zig");

pub const State = struct {
    current: Sequence,

    pub fn init() State {
        return State{ .current = Sequence{ .title = Title.init() } };
    }

    pub fn update(self: *State) void {
        const sequence = self.current.update() orelse return;

        var old = self.current;
        self.current = switch (sequence) {
            .title => .{ .title = Title.init() },
            .select => .{ .select = Select.init() },
            .stage => |level| .{ .stage = stage.init(level) orelse return },
        };
        old.deinit();
    }

    pub fn draw(self: State) void {
        self.current.draw();
    }

    pub fn deinit(self: *State) void {
        self.current.deinit();
    }
};

const Sequence = union(stage.SequenceType) {
    title: Title,
    select: Select,
    stage: stage.Stage,

    fn update(self: *Sequence) ?stage.SequenceData {
        return switch (self.*) {
            inline else => |*case| case.update(),
        };
    }

    fn draw(self: Sequence) void {
        engine.beginDraw();
        defer engine.endDraw();

        switch (self) {
            inline else => |sequence| sequence.draw(),
        }
    }

    fn deinit(self: *Sequence) void {
        switch (self.*) {
            inline else => |*case| case.deinit(),
        }
    }
};

const Title = struct {
    title: engine.Image,
    cursor: engine.Image,
    onePlayer: bool = true,

    fn init() Title {
        return Title{
            .title = engine.Image.init("title.png"),
            .cursor = engine.Image.init("cursor.png"),
        };
    }

    fn update(self: *Title) ?stage.SequenceData {
        if (engine.isPressed(engine.Key.w) or engine.isPressed(engine.Key.s)) {
            self.onePlayer = !self.onePlayer;
        }

        const result = stage.SequenceData{ .stage = if (self.onePlayer) 1 else 2 };
        return if (engine.isPressed(engine.Key.space)) result else null;
    }

    fn draw(self: Title) void {
        self.title.draw();
        self.cursor.drawXY(220, if (self.onePlayer) 395 else 433);
    }

    fn deinit(self: Title) void {
        self.title.deinit();
        self.cursor.deinit();
    }
};

const Select = struct {
    texture: engine.Image,

    fn init() Select {
        return Select{ .texture = engine.Image.init("select.dds") };
    }

    fn update(_: Select) ?stage.SequenceData {
        const char = engine.getPressed();
        return if (char >= '1' and char <= '9')
            .{ .stage = char - '1' + 1 }
        else
            null;
    }

    fn draw(self: Select) void {
        self.texture.draw();
    }

    fn deinit(self: Select) void {
        self.texture.deinit();
    }
};
