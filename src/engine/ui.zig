const input = @import("input.zig");
const window = @import("window.zig");
const math = @import("math.zig");
const batch = @import("batch.zig");
const graphics = @import("graphics.zig");
const text = @import("text.zig");
const audio = @import("audio.zig");
const assets = @import("assets.zig");

pub const Button = struct {
    pub const State = enum { normal, hover, pressed };
    pub const Option = struct {
        nine: ?batch.NineOption = null,
    };

    rect: math.Rect,
    event: u8,
    label: []const u8 = "",
    option: Option = .{},
    normal: Visual = .{},
    hover: Visual = .{},
    pressed: Visual = .{},
};

pub const Visual = struct {
    image: ?graphics.ImageId = null,
    textColor: ?graphics.Color = null,
};

pub const Menu = struct {
    pub const Option = struct {
        hoverSound: ?[:0]const u8 = null,
        clickSound: ?[:0]const u8 = null,
    };

    position: math.Vector2 = .zero,
    buttons: []const Button = &.{},
    option: Option = .{},
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

    pub fn update(self: *Menu) ?u8 {
        const previous = self.hover;

        self.hover = blk: for (self.buttons, 0..) |button, index| {
            const rect = button.rect.move(self.position);
            if (rect.contains(window.mousePosition)) break :blk index;
        } else null;

        const hover = self.hover orelse {
            self.pressed = null;
            return null;
        };

        if (hover != previous) {
            if (self.option.hoverSound) |sound| audio.playSound(sound);
        }

        if (input.mouse.pressed(.LEFT)) self.pressed = hover;
        if (input.mouse.released(.LEFT)) {
            defer self.pressed = null;
            if (self.pressed) |pressed| {
                if (pressed == hover) {
                    if (self.option.clickSound) |sound| audio.playSound(sound);
                    return self.buttons[hover].event;
                }
            }
        }

        return null;
    }

    pub fn draw(self: Menu) void {
        for (self.buttons, 0..) |button, index| {
            self.drawButton(button, index);
        }
    }

    pub fn buttonState(self: Menu, index: usize) Button.State {
        if (self.pressed) |pressed| {
            if (pressed == index and self.hover == index) return .pressed;
        }

        if (self.hover) |hover| {
            if (hover == index) return .hover;
        }

        return .normal;
    }

    fn drawButton(self: Menu, button: Button, index: usize) void {
        const state = self.buttonState(index);
        const visual = switch (state) {
            .normal => button.normal,
            .hover => button.hover,
            .pressed => button.pressed,
        };
        const rect = button.rect.move(self.position);

        if (visual.image) |imageId| {
            const image = assets.getImage(imageId).?;
            if (button.option.nine) |nine| {
                batch.drawNine(image, rect, nine);
            } else {
                batch.drawImage(image, rect.min, .{
                    .size = rect.size,
                });
            }
        }

        if (button.label.len == 0) return;
        text.drawString(button.label, rect.center(), .{
            .color = visual.textColor,
            .alignment = .center,
        });
    }
};
