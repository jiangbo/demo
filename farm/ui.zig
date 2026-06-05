const zhu = @import("zhu");

pub const debug = @import("ui/debug.zig");
pub const dialog = @import("ui/dialog.zig");
pub const pause = @import("ui/pause.zig");
pub const save_slot = @import("ui/save_slot.zig");
pub const toolbar = @import("ui/toolbar.zig");

const context = @import("context.zig");
const light = @import("system/light.zig");
const target = @import("system/target.zig");
const time = @import("system/time.zig");

pub const title = struct {
    const MenuEvent = enum(u8) { start, load, exit };

    const menus: []const zhu.widget.Menu = @import("zon/menu.zon");
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
        zhu.camera.mode = .window;
        zhu.audio.playMusic("assets/audio/02_spring_fairy_tale.ogg");
        mainMenu.reset();
        pauseMenu.reset();
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
    debug.init();
    title.init();
    pause.init();
    save_slot.init();
}

pub fn deinit() void {
    debug.deinit();
}

pub fn draw(world: *zhu.ecs.World) void {
    target.draw(world);
    light.draw(world);

    const previousMode = zhu.camera.mode;
    zhu.camera.mode = .window;
    defer zhu.camera.mode = previousMode;

    time.draw();
    toolbar.draw();
    dialog.draw(world);
}
