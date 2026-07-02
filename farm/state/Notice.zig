const zhu = @import("zhu");

pub const Entry = struct {
    timer: f32 = 0,
    text: []const u8 = &.{},
    buffer: [192]u8 = undefined,
};

entry: Entry = .{},
bubbleImage: zhu.NineImage = undefined,

pub fn init(self: *@This()) void {
    const image = zhu.getImage("farm-rpg/UI/dialogue box.png").?;
    self.bubbleImage = zhu.NineImage.from(image, .{
        .rect = .init(.xy(0, 48), .xy(48, 48)),
        .patch = .{ .min = .xy(3, 4), .max = .xy(3, 3) },
    });
}

pub fn reset(self: *@This()) void {
    self.entry = .{};
}

pub fn show(self: *@This(), comptime fmt: []const u8, args: anytype) void {
    const current = &self.entry;
    current.text = zhu.format(&current.buffer, fmt, args);
    current.timer = 2.0;
}

pub fn state(self: *@This()) *Entry {
    return &self.entry;
}

pub fn update(self: *@This(), delta: f32) void {
    if (self.entry.timer <= 0) return;
    self.entry.timer -= delta;
}

pub fn draw(self: *@This()) void {
    if (self.entry.timer <= 0) return;

    const option = zhu.text.Option{ .color = .black, .max = 168 };
    const textSize = zhu.text.measure(self.entry.text, option);
    const size = textSize.add(.xy(18, 14)).max(.xy(176, 40));
    const pos = zhu.window.size.sub(size).sub(.xy(12, 58));
    const rect: zhu.Rect = .init(pos, size);

    // 物品提示固定在快捷栏上方，和头顶世界提示区分开。
    zhu.batch.drawNine(self.bubbleImage, rect);
    zhu.text.draw(self.entry.text, rect.min.add(.xy(9, 7)), option);
}
