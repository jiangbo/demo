const std = @import("std");
const zhu = @import("zhu");

pub const save_slot = @import("ui/save_slot.zig");

const component = @import("component.zig");
const context = @import("context.zig");
const inventory = @import("inventory.zig");
const menus: []const zhu.widget.Menu = @import("zon/menu.zon");

var bubbleImage: zhu.NineImage = undefined;

pub fn init() void {
    // 与 C++ 的 dialogue_bubble preset 使用同一张九宫格图片。
    const image = zhu.getImage("farm-rpg/UI/dialogue box.png").?;
    bubbleImage = zhu.NineImage.from(image, .{
        .rect = .init(.xy(0, 48), .xy(48, 48)),
        .patch = .{ .min = .xy(3, 4), .max = .xy(3, 3) },
    });

    save_slot.init();
    rest.init();
}

pub fn deinit() void {}

pub fn draw(world: *zhu.ecs.World) void {
    dialog.draw(world);
    notice.draw(world);
    inventory.draw();
}

pub const overlay = struct {
    const Popup = enum { save, rest, pause };
    pub const Result = union(enum) { block, title, rest: u8 };

    var popup: ?Popup = null;
    var message: ?save_slot.Message = null;

    pub fn active() bool {
        return popup != null;
    }

    pub fn close() void {
        popup = null;
        message = null;
    }

    pub fn openRest() void {
        rest.enter();
        popup = .rest;
        message = null;
    }

    pub fn update(world: *zhu.ecs.World) ?Result {
        if (popup) |activePopup| {
            switch (activePopup) {
                .save => {
                    if (save_slot.update(world)) |result| {
                        switch (result) {
                            .close => popup = null,
                            .message => |next| {
                                message = next;
                                popup = .pause;
                            },
                            .farmLoad => unreachable,
                        }
                    }
                    if (save_slot.takeClosePause()) popup = null;
                },
                .rest => if (rest.update()) |req| switch (req) {
                    .close => popup = null,
                    .rest => |hours| {
                        popup = null;
                        return .{ .rest = hours };
                    },
                },
                .pause => if (pause.update()) |req| switch (req) {
                    .close => popup = null,
                    .save => {
                        save_slot.enter(.pauseSave);
                        popup = .save;
                    },
                    .load => {
                        save_slot.enter(.pauseLoad);
                        popup = .save;
                    },
                    .title => return .title,
                },
            }
            return .block;
        }

        if (!context.input.pressed(.pause)) return null;
        pause.enter(&.{});
        popup = .pause;
        message = null;
        return .block;
    }

    pub fn draw() void {
        switch (popup orelse return) {
            .save => save_slot.draw(),
            .rest => rest.draw(),
            .pause => pause.draw(),
        }

        const current = message orelse return;
        var color = zhu.Color.rgb(0.25, 1.0, 0.25);
        if (current.fail) color = .rgb(1.0, 0.25, 0.25);
        zhu.text.draw(current.text, .xy(zhu.window.size.x * 0.5, 32), .{
            .anchor = .center,
            .color = color,
        });
    }
};

pub const notice = struct {
    pub fn update(delta: f32) void {
        for (std.enums.values(context.notice.Channel)) |channel| {
            const state = context.notice.state(channel);
            if (state.timer <= 0) continue;
            state.timer -= delta;
        }
    }

    pub fn draw(world: *zhu.ecs.World) void {
        const player = world.getIdentity(component.actor.Player).?;
        const position = world.get(player, component.Position).?;

        const worldState = context.notice.state(.world);
        if (worldState.timer > 0) drawBubble(position, worldState.text);

        const itemState = context.notice.state(.item);
        if (itemState.timer > 0) drawItemNotice(itemState.text);
    }
};

pub const rest = struct {
    const MenuEvent = enum(u8) { minus, plus, ok, cancel };
    pub const Request = union(enum) { close, rest: u8 };

    var hours: u8 = 8;
    var menu: zhu.widget.Menu = menus[5];

    pub fn init() void {
        menu.centerInWindow();
    }

    pub fn enter() void {
        hours = 8;
    }

    pub fn update() ?Request {
        if (context.input.pressed(.pause)) {
            return .close;
        }

        const event = menu.update() orelse return null;
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

pub const pause = struct {
    const panelSize: zhu.Vector2 = .{ .x = 208, .y = 344 };
    pub const Request = enum { close, save, load, title };

    var menu: zhu.widget.Menu = menus[2];

    pub fn enter(disabled: []const usize) void {
        menu.disabled = disabled;
        menu.position = zhu.window.size.sub(panelSize).scale(0.5);
    }

    pub fn update() ?Request {
        if (context.input.pressed(.pause)) return .close;

        if (menu.update()) |event| switch (event) {
            0 => return .close,
            1 => return .save, // 选择槽位后保存
            2 => return .load, // 选择槽位后读取
            3 => return .title,
            4 => {
                // 时钟倍率不能减到 0，否则游戏时间会停止推进。
                const max = @max(0.1, context.clock.speed - 0.1);
                context.clock.speed = max;
            },
            5 => context.clock.speed += 0.1, // 加速
            6 => zhu.audio.changeMusicVolume(-0.1), // 减小音乐
            7 => zhu.audio.changeMusicVolume(0.1), // 增大音乐
            8 => zhu.audio.changeSoundVolume(-0.1), // 减小音效
            9 => zhu.audio.changeSoundVolume(0.1), // 增加音效
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
                0 => zhu.format(&buffer, "Speed {d:.2}x", .{
                    context.clock.speed,
                }),
                1 => zhu.format(&buffer, "Music {d:.0}%", .{
                    zhu.audio.musicVolume.load(.acquire) * 100,
                }),
                2 => zhu.format(&buffer, "SFX {d:.0}%", .{
                    zhu.audio.soundVolume.load(.acquire) * 100,
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
        const state = world.get(entity, Dialog).?;
        if (state.index >= state.lines.len) return;

        const text = state.lines[state.index];

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

fn drawItemNotice(text: []const u8) void {
    const option = zhu.text.Option{ .color = .black, .max = 168 };
    const textSize = zhu.text.measure(text, option);
    const size = textSize.add(.xy(18, 14)).max(.xy(176, 40));
    const pos = zhu.window.size.sub(size).sub(.xy(12, 58));
    const rect: zhu.Rect = .init(pos, size);

    // 物品提示固定在快捷栏上方，和头顶世界提示区分开。
    zhu.batch.drawNine(bubbleImage, rect);
    zhu.text.draw(text, rect.min.add(.xy(9, 7)), option);
}
