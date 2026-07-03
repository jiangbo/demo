const std = @import("std");
const zhu = @import("zhu");

const input = @import("input.zig");
const inventory = @import("global/Inventory.zig");
const notice = @import("ui/notice.zig");
const store = @import("save.zig");
const rest = @import("ui/rest.zig");
const time = @import("ui/time.zig");
const menus: []const zhu.widget.Menu = @import("zon/menu.zon");

pub const pause = @import("ui/pause.zig");

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
    notice.init();
    time.init();
    pause.cfg = args.config;
    save.init(args.slots);
    rest.init();
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
    time.draw(world);
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
