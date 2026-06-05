const zhu = @import("zhu");

const context = @import("context.zig");
const ui = @import("ui.zig");

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
            .load => ui.save_slot.enter(.titleLoad),
            .exit => zhu.window.exit(),
        }
    }

    if (pauseMenu.update() != null) ui.pause.enter(true);
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
