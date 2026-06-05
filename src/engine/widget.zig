const input = @import("input.zig");
const window = @import("window.zig");
const math = @import("math.zig");
const batch = @import("batch.zig");
const graphics = @import("graphics.zig");
const text = @import("text.zig");
const audio = @import("audio.zig");
const assets = @import("assets.zig");

const Vector2 = math.Vector2;

pub const Button = struct {
    pub const State = enum { normal, hover, pressed, disabled };
    pub const Style = struct {
        image: ?graphics.ImageId = null,
        source: ?math.Rect = null,
        text: text.Option = .{},
    };

    rect: math.Rect,
    event: u8,
    label: []const u8 = "",
    nine: ?batch.NineOption = null,
    normal: Style = .{},
    hover: Style = .{},
    pressed: Style = .{},
    disabled: Style = .{},

    /// 根据状态返回对应样式
    pub fn style(self: Button, state: State) Style {
        return switch (state) {
            .normal => self.normal,
            .hover => self.hover,
            .pressed => self.pressed,
            .disabled => self.disabled,
        };
    }

    /// 绘制按钮背景图
    pub fn drawImage(self: Button, state: State, offset: Vector2) void {
        const visual = self.style(state);
        var image = assets.getImage(visual.image orelse return).?;
        if (visual.source) |source| image = image.sub(source);

        const rect = self.rect.move(offset);
        if (self.nine) |nine| batch.drawNine(image, rect, nine) else {
            batch.drawImage(image, rect.min, .{ .size = rect.size });
        }
    }

    /// 绘制按钮文字
    pub fn drawText(self: Button, state: State, offset: Vector2) void {
        if (self.label.len == 0) return;

        var option = self.style(state).text;
        const rect = self.rect.move(offset);
        if (option.alignment == null) option.alignment = .center;
        text.drawString(self.label, rect.center(), option);
    }
};

pub const Menu = struct {
    position: math.Vector2 = .zero,
    overlay: ?graphics.Color = null,
    panel: struct {
        size: math.Vector2 = .zero,
        color: ?graphics.Color = null,
        image: ?graphics.ImageId = null,
        source: ?math.Rect = null,
    } = .{},
    title: struct {
        text: []const u8 = "",
        position: math.Vector2 = .zero,
        option: text.Option = .{ .alignment = .center },
    } = .{},
    buttons: []const Button = &.{},
    hoverSound: ?[:0]const u8 = null,
    clickSound: ?[:0]const u8 = null,
    disabled: []const usize = &.{},
    hover: ?usize = null,
    pressed: ?usize = null,

    pub fn init(position: math.Vector2, menu: Menu) Menu {
        var result = menu;
        result.position = position;
        result.hover = null;
        result.pressed = null;
        return result;
    }

    pub fn reset(self: *Menu) void {
        self.hover = null;
        self.pressed = null;
    }

    pub fn centerInWindow(self: *Menu) void {
        self.position = window.size.sub(self.panel.size).scale(0.5);
    }

    pub fn update(self: *Menu) ?u8 {
        const previous = self.hover;

        self.hover = blk: for (self.buttons, 0..) |button, index| {
            if (self.isDisabled(index)) continue;
            const rect = button.rect.move(self.position);
            if (rect.contains(window.mouse)) break :blk index;
        } else null;

        const hover = self.hover orelse {
            self.pressed = null;
            return null;
        };

        if (hover != previous) if (self.hoverSound) |sound| {
            audio.playSound(sound);
        };

        if (input.mouse.pressed(.LEFT)) self.pressed = hover;
        if (!input.mouse.released(.LEFT)) return null;
        defer self.pressed = null;

        const pressed = self.pressed orelse return null;
        if (pressed != hover) return null;

        if (self.clickSound) |sound| audio.playSound(sound);
        return self.buttons[hover].event;
    }

    pub fn draw(self: Menu) void {
        if (self.overlay) |overlay| {
            const rect: math.Rect = .init(.zero, window.size);
            batch.drawRect(rect, .{ .color = overlay });
        }
        self.drawPanel();

        for (self.buttons, 0..) |button, index| {
            button.drawImage(self.buttonState(index), self.position);
        }

        const title = self.title;
        if (title.text.len != 0) {
            const position = self.position.add(title.position);
            text.drawString(title.text, position, title.option);
        }

        for (self.buttons, 0..) |button, index| {
            button.drawText(self.buttonState(index), self.position);
        }
    }

    pub fn drawText(self: Menu, index: usize, value: []const u8) void {
        var button = self.buttons[index];
        button.label = value;
        button.drawText(self.buttonState(index), self.position);
    }

    fn drawPanel(self: Menu) void {
        const rect = math.Rect.init(self.position, self.panel.size);
        if (self.panel.color) |color| {
            batch.drawRect(rect, .{ .color = color });
        }

        var image = assets.getImage(self.panel.image orelse return).?;
        if (self.panel.source) |source| image = image.sub(source);
        batch.drawImage(image, rect.min, .{ .size = rect.size });
    }

    pub fn buttonState(self: Menu, index: usize) Button.State {
        if (self.isDisabled(index)) return .disabled;

        if (self.pressed) |pressed| {
            const active = pressed == index and self.hover == index;
            if (active) return .pressed;
        }

        if (self.hover) |hover| if (hover == index) return .hover;
        return .normal;
    }

    fn isDisabled(self: Menu, index: usize) bool {
        for (self.disabled) |d| if (d == index) return true;
        return false;
    }
};
