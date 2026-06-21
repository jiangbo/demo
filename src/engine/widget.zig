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

pub const Popup = struct {
    anchor: Vector2,
    size: Vector2,
    offset: Vector2 = .zero,
    bounds: ?Vector2 = null,
};

pub fn popupPosition(popup: Popup) Vector2 {
    const bounds = popup.bounds orelse window.size;
    var pos = popup.anchor.add(popup.offset);

    if (pos.x + popup.size.x > bounds.x) {
        pos.x = popup.anchor.x - popup.offset.x - popup.size.x;
    }
    if (pos.y + popup.size.y > bounds.y) {
        pos.y = popup.anchor.y - popup.offset.y - popup.size.y;
    }

    return pos.clamp(.zero, bounds.sub(popup.size).max(.zero));
}

pub fn StackStore(comptime T: type) type {
    return struct {
        pub const Stack = struct { item: T, count: u32 = 0 };
        pub const Add = struct {
            item: T,
            count: u32 = 1,
            limit: ?u32 = null,
        };
        pub const Put = struct {
            removes: []const Remove = &.{},
            adds: []const Add = &.{},
        };
        pub const Remove = struct { index: usize, count: u32 = 1 };
        pub const Entry = struct {
            index: usize,
            item: T,
            count: u32,

            pub fn init(index: usize, item: T, count: u32) Entry {
                return .{ .index = index, .item = item, .count = count };
            }
        };
        pub const Change = union(enum) { add: Entry, remove: Entry };
        pub const Move = enum { merge, clear, swap };
        pub const Result = struct {
            status: enum { done, fail },
            // fail 时背包已回滚，changes 可由调用者选择性提交。
            changes: []const Change,
        };

        stacks: []Stack,
        limit: u32,

        pub fn init(stacks: []Stack, limit: u32) @This() {
            return .{ .stacks = stacks, .limit = limit };
        }

        pub fn add(self: *@This(), args: Add) u32 {
            var addArgs = args;
            while (addArgs.count > 0) {
                if (self.addOne(addArgs)) |placed| {
                    addArgs.count -= placed.count;
                } else break;
            }
            return addArgs.count;
        }

        pub fn addUnstacked(self: *@This(), item: T) bool {
            return self.fill(.{ .item = item }, 1) != null;
        }

        pub fn get(self: *@This(), index: usize) ?Stack {
            return if (self.getPtr(index)) |ptr| ptr.* else null;
        }

        pub fn getPtr(self: *@This(), index: usize) ?*Stack {
            if (self.stacks[index].count == 0) return null;
            return &self.stacks[index];
        }

        pub fn first(self: *const @This(), item: T) ?usize {
            for (self.stacks, 0..) |*stack, index| {
                if (stack.count == 0) continue;
                if (std.meta.eql(stack.item, item)) return index;
            }
            return null;
        }

        pub fn firstEmpty(self: *const @This()) ?usize {
            for (self.stacks, 0..) |*stack, index| {
                if (stack.count == 0) return index;
            }
            return null;
        }

        pub fn clearAt(self: *@This(), index: usize) void {
            self.stacks[index].count = 0;
        }

        pub fn clear(self: *@This()) void {
            for (self.stacks) |*stack| stack.count = 0;
        }

        pub fn move(self: *@This(), from: usize, to: usize, limit: u32) ?Move {
            if (from == to) return null;

            const source = &self.stacks[from];
            const target = &self.stacks[to];
            if (source.count == 0) return null;
            const empty = target.count == 0;
            if (empty or !std.meta.eql(source.item, target.item)) {
                std.mem.swap(Stack, source, target);
                return .swap;
            }

            if (target.count >= limit) return null;

            const moved = @min(limit - target.count, source.count);
            target.count += moved;
            source.count -= moved;
            return if (source.count > 0) .merge else .clear;
        }

        pub fn tryPut(self: *@This(), buf: []Change, ops: Put) Result {
            var list = std.ArrayList(Change).initBuffer(buf);
            var done = blk: for (ops.removes) |entry| {
                if (entry.count == 0) continue;
                const taken = self.take(entry.index, entry.count) //
                    orelse break :blk false;
                list.appendAssumeCapacity(.{ .remove = taken });
            } else true;

            if (done) done = blk: for (ops.adds) |entry| {
                var addArgs = entry;
                while (addArgs.count > 0) {
                    if (self.addOne(addArgs)) |placed| {
                        addArgs.count -= placed.count;
                        list.appendAssumeCapacity(.{ .add = placed });
                    } else break :blk false;
                }
            } else true;

            if (done) return .{ .status = .done, .changes = list.items };
            self.back(list.items);
            return .{ .status = .fail, .changes = list.items };
        }

        pub fn put(self: *@This(), changes: []const Change) void {
            for (changes) |change| self.putOne(change);
        }

        pub fn back(self: *@This(), changes: []const Change) void {
            var iterator = std.mem.reverseIterator(changes);
            while (iterator.next()) |change| {
                switch (change) {
                    .add => |entry| self.putOne(.{ .remove = entry }),
                    .remove => |entry| self.putOne(.{ .add = entry }),
                }
            }
        }

        fn addOne(self: *@This(), args: Add) ?Entry {
            const limit = args.limit orelse self.limit;
            std.debug.assert(limit > 0);

            if (limit > 1) if (self.merge(args, limit)) |e| return e;
            return self.fill(args, limit);
        }

        pub fn take(self: *@This(), index: usize, count: u32) ?Entry {
            std.debug.assert(count > 0);
            const stack = self.getPtr(index) orelse return null;
            if (stack.count < count) return null;

            const entry = Entry.init(index, stack.item, count);
            stack.count -= count;
            return entry;
        }

        pub fn takeAdd(self: *@This(), index: usize, args: Add) bool {
            var changes: [16]Change = undefined;
            const result = self.tryPut(&changes, .{
                .removes = &.{.{ .index = index }},
                .adds = &.{args},
            });
            return result.status == .done;
        }

        fn merge(self: *@This(), args: Add, limit: u32) ?Entry {
            for (0..self.stacks.len) |index| {
                const stack = self.getPtr(index) orelse continue;
                if (!std.meta.eql(stack.item, args.item)) continue;
                if (stack.count >= limit) continue;

                const moved = @min(limit - stack.count, args.count);
                stack.count += moved;
                return .init(index, args.item, moved);
            }
            return null;
        }

        fn fill(self: *@This(), args: Add, limit: u32) ?Entry {
            for (self.stacks, 0..) |*stack, index| {
                if (stack.count != 0) continue;

                const moved = @min(limit, args.count);
                stack.* = .{ .item = args.item, .count = moved };
                return .init(index, args.item, moved);
            }
            return null;
        }

        fn putOne(self: *@This(), change: Change) void {
            switch (change) {
                .add => |entry| {
                    const stack = &self.stacks[entry.index];
                    if (stack.count == 0) stack.item = entry.item;
                    std.debug.assert(std.meta.eql(entry.item, stack.item));
                    stack.count += entry.count;
                },
                .remove => |entry| {
                    const taken = self.take(entry.index, entry.count).?;
                    std.debug.assert(std.meta.eql(entry.item, taken.item));
                },
            }
        }
    };
}

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
