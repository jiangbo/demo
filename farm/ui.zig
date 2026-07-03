const std = @import("std");
const zhu = @import("zhu");

const component = @import("component.zig");
const input = @import("input.zig");
const inventory = @import("global/Inventory.zig");
const notice = @import("ui/notice.zig");
const store = @import("save.zig");
const menus: []const zhu.widget.Menu = @import("zon/menu.zon");

var bubbleImage: zhu.NineImage = undefined;

pub const Message = struct { text: []const u8, fail: bool };
pub const UiRequest = union(enum) {
    block,
    title,
    rest: u8,
    save: u8,
    load: u8,
};
const Popup = enum { save, rest, pause };

var activePopup: ?Popup = null;
var popupMessage: ?Message = null;

pub const Init = struct {
    slots: []const save.Slot,
    config: *store.Config,
};

pub fn init(args: Init) void {
    const image = zhu.getImage("farm-rpg/UI/dialogue box.png").?;
    bubbleImage = zhu.NineImage.from(image, .{
        .rect = .init(.xy(0, 48), .xy(48, 48)),
        .patch = .{ .min = .xy(3, 4), .max = .xy(3, 3) },
    });

    notice.init();
    pause.cfg = args.config;
    save.init(args.slots);
    rest.menu.centerInWindow();
}

pub fn deinit() void {}

pub fn openPause() void {
    pause.open(.play);
    activePopup = .pause;
}

pub fn openRest() void {
    rest.hours = 8;
    activePopup = .rest;
}

pub fn update(world: *zhu.ecs.World, delta: f32) ?UiRequest {
    notice.update(world, delta);

    if (activePopup) |active| {
        if (updatePopup(active)) |req| return req;
        return .block;
    }

    if (!input.pressed(.pause)) return null;
    openPause();
    return .block;
}

fn updatePopup(active: Popup) ?UiRequest {
    switch (active) {
        .save => {
            if (save.update()) |result| {
                switch (result) {
                    .close => close(),
                    .save => |slot| {
                        activePopup = .pause;
                        return .{ .save = slot };
                    },
                    .load => |slot| {
                        activePopup = .pause;
                        return .{ .load = slot };
                    },
                }
            }
        },
        .rest => if (rest.update()) |req| switch (req) {
            .close => close(),
            .rest => |hours| {
                close();
                return .{ .rest = hours };
            },
        },
        .pause => if (pause.update()) |req| switch (req) {
            .close => close(),
            .save => {
                popupMessage = null;
                save.open(.save);
                activePopup = .save;
            },
            .load => {
                popupMessage = null;
                save.open(.load);
                activePopup = .save;
            },
            .title => return .title,
        },
    }
    return null;
}

pub fn showMessage(next: Message) void {
    popupMessage = next;
}

pub fn close() void {
    activePopup = null;
    popupMessage = null;
}

pub fn draw(world: *zhu.ecs.World) void {
    dialog.draw(world);
    world.getPtr(world.entity, inventory.Inventory).?.draw();

    if (activePopup) |active| {
        switch (active) {
            .save => save.draw(),
            .rest => rest.draw(),
            .pause => pause.draw(),
        }
    }

    if (popupMessage) |current| {
        var color = zhu.Color.rgb(0.25, 1.0, 0.25);
        if (current.fail) color = .rgb(1.0, 0.25, 0.25);
        zhu.text.draw(current.text, .xy(zhu.window.size.x * 0.5, 32), .{
            .anchor = .center,
            .color = color,
        });
    }

    notice.draw(world);
}

pub const rest = struct {
    const MenuEvent = enum(u8) { minus, plus, ok, cancel };
    pub const Request = union(enum) { close, rest: u8 };

    var hours: u8 = 8;
    var menu: zhu.widget.Menu = menus[5];

    pub fn update() ?Request {
        const event = menu.update(.{}) orelse return null;
        switch (@as(MenuEvent, @enumFromInt(event))) {
            .minus => hours -= 1,
            .plus => hours += 1,
            .ok => return .{ .rest = hours },
            .cancel => return .close,
        }
        hours = std.math.clamp(hours, 1, 24);
        return null;
    }

    pub fn draw() void {
        menu.draw();

        const position = menu.position.add(.xy(140, 82));
        zhu.text.drawFmt("{d}h", .{hours}, position, .{
            .anchor = .center,
        });
    }
};

pub const save = struct {
    pub const Mode = enum { load, save };
    pub const Request = union(enum) { close, save: u8, load: u8 };
    pub const Slot = store.Slot;

    var mode: Mode = .load;
    var slots: []const Slot = &.{};
    var confirmSlot: ?u8 = null;
    var confirmTitleBuffer: [40]u8 = undefined;
    var disabledSlots: [store.slotCount]usize = undefined;
    var disabledCount: usize = 0;
    var slotMenu: zhu.widget.Menu = menus[3];
    var confirmMenu: zhu.widget.Menu = menus[4];

    pub fn init(slotStates: []const Slot) void {
        slots = slotStates;
        slotMenu.centerInWindow();
        confirmMenu.centerInWindow();
    }

    pub fn open(next: Mode) void {
        mode = next;
        confirmSlot = null;
        rebuildDisabled();
        slotMenu.title.text = switch (mode) {
            .load => "Load Game",
            .save => "Save Game",
        };
        confirmMenu.title.text = "";
    }

    pub fn update() ?Request {
        if (confirmSlot) |slot| {
            if (confirmMenu.update(.{})) |event| {
                switch (event) {
                    0 => {
                        confirmSlot = null;
                        return .{ .save = slot };
                    },
                    1 => confirmSlot = null,
                    else => unreachable,
                }
            }
            return null;
        }

        if (slotMenu.update(.{})) |event| {
            const backEvent: u8 = @intCast(slots.len);
            if (event == backEvent) {
                return .close;
            }
            return chooseSlot(event);
        }
        return null;
    }

    pub fn draw() void {
        slotMenu.draw();
        for (0..slots.len) |index| drawSlot(index);
        if (confirmSlot != null) confirmMenu.draw();
    }

    fn rebuildDisabled() void {
        disabledCount = 0;
        for (0..slots.len) |index| {
            if (slotEnabled(index)) continue;
            disabledSlots[disabledCount] = index;
            disabledCount += 1;
        }
        slotMenu.disabled = disabledSlots[0..disabledCount];
    }

    fn chooseSlot(slot: usize) ?Request {
        switch (mode) {
            .load => return .{ .load = @intCast(slot) },
            .save => {
                if (slotHasFile(slot)) {
                    confirmSlot = @intCast(slot);
                    confirmMenu.title.text = zhu.format(
                        &confirmTitleBuffer,
                        "Overwrite slot {d}?",
                        .{slot + 1},
                    );
                    return null;
                }
                return .{ .save = @intCast(slot) };
            },
        }
    }

    fn drawSlot(index: usize) void {
        var buffer: [56]u8 = undefined;
        const label = switch (slots[index]) {
            .empty => zhu.format(&buffer, "Slot {d} Empty", .{index + 1}),
            .invalid => zhu.format(&buffer, "Slot {d} Invalid", .{
                index + 1,
            }),
            .valid => |summary| zhu.format(&buffer, "Slot {d} Day {d}", .{
                index + 1,
                summary.day,
            }),
        };

        slotMenu.drawText(index, label);
    }

    fn slotEnabled(index: usize) bool {
        return switch (mode) {
            .save => true,
            .load => switch (slots[index]) {
                .valid => true,
                .empty, .invalid => false,
            },
        };
    }

    fn slotHasFile(index: usize) bool {
        return switch (slots[index]) {
            .empty => false,
            .invalid, .valid => true,
        };
    }
};

pub const pause = struct {
    const panelSize: zhu.Vector2 = .{ .x = 208, .y = 344 };
    const Mode = enum { title, play };
    pub const Request = enum { close, save, load, title };

    var cfg: *store.Config = undefined;
    var menu: zhu.widget.Menu = menus[2];

    pub fn open(mode: Mode) void {
        menu.disabled = switch (mode) {
            .title => &.{ 1, 2, 3 },
            .play => &.{},
        };
        menu.position = zhu.window.size.sub(panelSize).scale(0.5);
    }

    pub fn update() ?Request {
        if (menu.update(.{})) |event| switch (event) {
            0 => return .close,
            1 => return .save, // 选择槽位后保存
            2 => return .load, // 选择槽位后读取
            3 => return .title,
            4 => cfg.speed = @max(0.1, cfg.speed - 0.1),
            5 => cfg.speed += 0.1, // 加速
            6 => cfg.music = zhu.clamp(cfg.music - 0.1, 0, 1),
            7 => cfg.music = zhu.clamp(cfg.music + 0.1, 0, 1),
            8 => cfg.sound = zhu.clamp(cfg.sound - 0.1, 0, 1),
            9 => cfg.sound = zhu.clamp(cfg.sound + 0.1, 0, 1),
            else => unreachable,
        };
        return null;
    }

    pub fn draw() void {
        // 全屏覆盖
        const overlayRect = zhu.Rect.init(.zero, zhu.window.size);
        zhu.batch.drawRect(overlayRect, .{ .color = .gray(0, 0.35) });

        // 暂停面板背景
        const back = zhu.Rect.init(menu.position, panelSize);
        zhu.batch.drawRect(back, .{ .color = .gray(0, 0.45) });

        menu.draw();

        for (0..3) |index| {
            var buffer: [40]u8 = undefined;
            const string: []const u8 = switch (index) {
                0 => zhu.format(&buffer, "Speed {d:.2}x", .{cfg.speed}),
                1 => zhu.format(&buffer, "Music {d:.0}%", .{
                    cfg.music * 100,
                }),
                2 => zhu.format(&buffer, "SFX {d:.0}%", .{
                    cfg.sound * 100,
                }),
                else => unreachable,
            };

            const y = 212 + @as(f32, @floatFromInt(index)) * 38;
            const rect = zhu.Rect.init(.xy(24, y), .xy(160, 32));
            const pos = rect.move(menu.position).center();
            zhu.text.draw(string, pos, .{
                .anchor = .center,
            });
        }
    }
};

pub const dialog = struct {
    // 对话气泡只读取 talk 系统维护的当前对话状态。
    pub fn draw(world: *zhu.ecs.World) void {
        const Dialog = component.actor.Dialog;

        const entity = world.getIdentity(Dialog) orelse return;
        const dialogState = world.get(entity, Dialog).?;
        if (dialogState.index >= dialogState.lines.len) return;

        const text = dialogState.lines[dialogState.index];

        const pos = world.get(entity, component.Position).?;
        drawBubble(pos, text);
    }
};

fn drawBubble(position: zhu.Vector2, text: []const u8) void {
    const head = zhu.camera.toWindow(position.addY(-24));
    const option = zhu.text.Option{ .color = .black, .max = 144 };
    const textSize = zhu.text.measure(text, option);
    const size = textSize.add(.xy(16, 16)).max(.xy(160, 48));

    // 对话气泡在窗口坐标取整，避免位图文字亚像素闪烁。
    const bubblePos = head.addXY(-size.x / 2, -4 - size.y).round();
    const bubbleRect: zhu.Rect = .init(bubblePos, size);
    zhu.batch.drawNine(bubbleImage, bubbleRect);

    zhu.text.draw(text, bubbleRect.min.add(.xy(8, 8)), option);
}
