const zhu = @import("zhu");
const ecs = @import("ecs");

const component = @import("../component.zig");
const zon = @import("../zon.zig");
const about = @import("about.zig");
const dialog = @import("dialog.zig");
const pause = @import("pause.zig");
const save = @import("save.zig");
const tip = @import("tip.zig");

const Dialog = component.dialog.Dialog;

pub const battle = @import("battle.zig");

pub const Request = union(enum) {
    block,
    dialog: zon.dialog.Event,
    status,
    item,
    load: u8,
    save: u8,
};

const Popup = enum { about, pause, save };

var popup: ?Popup = null;

pub fn init() void {
    about.init();
    dialog.init();
}

pub fn reset() void {
    popup = null;
    tip.reset();
}

pub fn openPause() void {
    popup = .pause;
}

pub fn update(world: *ecs.World, delta: f32) ?Request {
    tip.update(world, delta);
    if (world.has(world.entity, Dialog)) tip.reset();
    if (dialog.update(world)) |event| {
        return .{ .dialog = event };
    }

    const current = popup orelse return null;
    switch (current) {
        .pause => {
            const req = pause.update() orelse return .block;
            switch (req) {
                .status => {
                    popup = null;
                    return .status;
                },
                .item => {
                    popup = null;
                    return .item;
                },
                .load => {
                    save.open(.load);
                    popup = .save;
                },
                .save => {
                    save.open(.save);
                    popup = .save;
                },
                .about => popup = .about,
                .exit => zhu.window.exit(),
                .close => popup = null,
            }
        },
        .about => if (about.update(delta)) {
            popup = .pause;
        },
        .save => {
            const req = save.update() orelse return .block;
            switch (req) {
                .close => popup = .pause,
                .load => |index| {
                    popup = .pause;
                    return .{ .load = index };
                },
                .save => |index| {
                    popup = .pause;
                    return .{ .save = index };
                },
            }
        },
    }
    return .block;
}

pub fn draw(world: *ecs.World) void {
    dialog.draw(world);
    if (!world.has(world.entity, Dialog)) tip.draw();
    if (popup) |current| switch (current) {
        .about => about.draw(),
        .pause => pause.draw(),
        .save => save.draw(),
    };
}
