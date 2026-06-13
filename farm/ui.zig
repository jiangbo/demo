const zhu = @import("zhu");

pub const save_slot = @import("ui/save_slot.zig");
pub const toolbar = @import("ui/toolbar.zig");

const component = @import("component.zig");
const context = @import("context.zig");
const control = @import("system/control.zig");
const light = @import("system/light.zig");
const time = @import("system/time.zig");
const menus: []const zhu.widget.Menu = @import("zon/menu.zon");

pub const pause = struct {
    const panelSize: zhu.Vector2 = .{ .x = 208, .y = 344 };
    pub var active: bool = false;
    var menu: zhu.widget.Menu = menus[2];

    pub fn enter(disable: bool) void {
        active = true;
        menu.disabled = if (disable) &.{ 1, 2 } else &.{};
        menu.position = zhu.window.size.sub(panelSize).scale(0.5);
        menu.click = .empty;
    }

    pub fn update() void {
        if (menu.update()) |event| switch (event) {
            0 => active = false, // 继续游戏
            1 => save_slot.enter(.pauseSave), // 选择槽位后保存
            2 => save_slot.enter(.pauseLoad), // 选择槽位后读取
            3 => context.scene.request(.title), // 返回标题
            4 => context.clock.speed -= 0.1, // 减速
            5 => context.clock.speed += 0.1, // 加速
            6 => zhu.audio.changeMusicVolume(-0.1), // 减小音乐
            7 => zhu.audio.changeMusicVolume(0.1), // 增大音乐
            8 => zhu.audio.changeSoundVolume(-0.1), // 减小音效
            9 => zhu.audio.changeSoundVolume(0.1), // 增加音效
            else => unreachable,
        };
    }

    pub fn draw() void {
        // 全屏覆盖
        const overlay = zhu.Rect.init(.zero, zhu.window.size);
        zhu.batch.drawRect(overlay, .{ .color = .gray(0, 0.35) });

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
            zhu.text.drawString(string, pos, .{
                .alignment = .center,
            });
        }
    }
};

pub const dialog = struct {
    var image: zhu.Image = undefined;

    pub fn init() void {
        image = zhu.getImage("farm-rpg/UI/dialogue box.png").?
            .sub(.init(.xy(0, 48), .xy(48, 48)));
    }

    // 对话气泡只读取 talk 系统维护的当前对话状态。
    pub fn draw(world: *zhu.ecs.World) void {
        const Dialog = component.actor.Dialog;

        const entity = world.getIdentity(Dialog) orelse return;
        const state = world.get(entity, Dialog).?;
        if (state.index >= state.lines.len) return;

        const text = state.lines[state.index];

        const pos = world.get(entity, component.Position).?;
        const head = zhu.camera.toWindow(pos.addY(-30));
        const option = zhu.text.Option{ .color = .black, .max = 144 };
        const textSize = zhu.text.measure(text, option);
        const size = textSize.add(.xy(16, 16)).max(.xy(160, 48));

        const bubblePos = head.addXY(-size.x / 2, -4 - size.y);
        const bubbleRect: zhu.Rect = .init(bubblePos, size);
        zhu.batch.drawNine(image, bubbleRect, .{
            .topLeft = .xy(3, 4),
            .bottomRight = .xy(3, 3),
        });

        const textPos = bubbleRect.min.add(.xy(8, 8));
        zhu.text.drawString(text, textPos, option);
    }
};

pub const title = struct {
    const MenuEvent = enum(u8) { start, load, exit };

    var mainMenu: zhu.widget.Menu = menus[0];
    var pauseMenu: zhu.widget.Menu = menus[1];
    var background: zhu.Image = undefined;
    var logo: zhu.Image = undefined;
    var elapsed: f32 = 0;

    pub fn init() void {
        background = zhu.getImage("textures/UI/farm-rpg-bg.png").?;
        logo = zhu.getImage("textures/UI/farm-rpg-logo.png").?;
        const size = pauseMenu.buttons[0].rect.size;
        const x = zhu.window.size.x - 10 - size.x;
        pauseMenu.position = .xy(x, 10);
    }

    pub fn enter() void {
        zhu.camera.scale = .one;
        zhu.camera.mode = .window;
        zhu.audio.playMusic("assets/audio/02_spring_fairy_tale.ogg");
        mainMenu.click = .empty;
        pauseMenu.click = .empty;
    }

    pub fn exit() void {
        zhu.camera.mode = .world;
        zhu.audio.setMusicState(.stopped);
    }

    pub fn update(delta: f32) void {
        elapsed += delta;

        if (mainMenu.update()) |event| {
            switch (@as(MenuEvent, @enumFromInt(event))) {
                .start => context.scene.requestNewGame(),
                .load => save_slot.enter(.titleLoad),
                .exit => zhu.window.exit(),
            }
        }

        if (pauseMenu.update() != null) pause.enter(true);
    }

    pub fn draw() void {
        // 背景
        zhu.batch.drawImage(background, .zero, .{
            .size = zhu.window.size,
        });
        const y = 115 + @sin(elapsed * 2) * 5;
        zhu.batch.drawImage(logo, .xy(320, y), .{
            .size = .xy(293, 125),
            .anchor = .center,
        });

        mainMenu.draw();
        pauseMenu.draw();
    }
};

pub fn init() void {
    title.init();
    save_slot.init();
    dialog.init();
}

pub fn deinit() void {}

pub fn draw(world: *zhu.ecs.World) void {
    control.draw(world);
    light.draw(world);

    const previousMode = zhu.camera.mode;
    zhu.camera.mode = .window;
    defer zhu.camera.mode = previousMode;

    dialog.draw(world);
    time.draw();
    toolbar.draw();
}
