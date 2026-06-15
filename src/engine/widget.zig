const std = @import("std");

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
    patch: ?graphics.NineImage.Patch = null,
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
        if (self.patch) |patch| {
            return batch.drawNine(.init(image, patch), rect);
        }
        batch.drawImage(image, rect.min, .{ .size = rect.size });
    }

    /// 绘制按钮文字
    pub fn drawText(self: Button, state: State, offset: Vector2) void {
        if (self.label.len == 0) return;

        var option = self.style(state).text;
        const rect = self.rect.move(offset);
        if (option.anchor == null) option.anchor = .center;
        text.draw(self.label, rect.center(), option);
    }
};

pub fn ClickT(comptime T: type) type {
    return struct {
        hover: ?T = null,
        pressed: ?T = null,
        captured: bool = false,

        pub const empty: @This() = .{};

        pub fn update(self: *@This(), hover: ?T) ?T {
            self.hover = hover;
            self.captured = self.hover != null or self.pressed != null;

            if (hover) |value| {
                if (input.mouse.pressed(.LEFT)) self.pressed = value;
            }

            if (!input.mouse.released(.LEFT)) return null;
            defer self.pressed = null;
            if (!std.meta.eql(self.pressed, self.hover)) return null;
            return self.hover;
        }
    };
}

pub const Click = ClickT(usize);

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
        option: text.Option = .{ .anchor = .center },
    } = .{},
    buttons: []const Button = &.{},
    hoverSound: ?[:0]const u8 = null,
    clickSound: ?[:0]const u8 = null,
    disabled: []const usize = &.{},
    click: Click = .empty,

    pub fn init(position: math.Vector2, menu: Menu) Menu {
        var result = menu;
        result.position = position;
        result.click = .empty;
        return result;
    }

    pub fn centerInWindow(self: *Menu) void {
        self.position = window.size.sub(self.panel.size).scale(0.5);
    }

    pub fn update(self: *Menu) ?u8 {
        const previous = self.click.hover;

        const hover = blk: for (self.buttons, 0..) |button, index| {
            if (self.isDisabled(index)) continue;
            const rect = button.rect.move(self.position);
            if (rect.contains(window.mouse)) break :blk index;
        } else null;

        if (hover) |index| {
            if (index != previous) if (self.hoverSound) |sound| {
                audio.playSound(sound);
            };
        }

        const index = self.click.update(hover) orelse return null;
        if (self.clickSound) |sound| audio.playSound(sound);
        return self.buttons[index].event;
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
            text.draw(title.text, position, title.option);
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

        const hover = self.click.hover == index;
        if (self.click.pressed) |pressed| {
            if (pressed == index and hover) return .pressed;
        }
        return if (hover) .hover else .normal;
    }

    fn isDisabled(self: Menu, index: usize) bool {
        for (self.disabled) |d| if (d == index) return true;
        return false;
    }
};
