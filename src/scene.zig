const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const window = zhu.window;
const camera = zhu.camera;

const titleScene = @import("ui/title.zig");
const battleScene = @import("battle/battle.zig");
const component = @import("component.zig");
const map = @import("map.zig");
const system = @import("system/system.zig");
const ui = @import("ui/ui.zig");
const zon = @import("zon.zig");

const Dialog = component.dialog.Dialog;
const Enemy = component.actor.Enemy;
const Interact = component.Interact;
const Player = component.actor.Player;

const WorldEntry = union(enum) {
    start,
    battle,
    load: u8,
    loadPause: u8,
};

const Scene = union(enum) {
    title,
    world: WorldEntry,
    battle,
};

const SceneType = std.meta.Tag(Scene);

// 管理场景切换时的淡入淡出状态。
const Fade = struct {
    timer: ?zhu.Timer = null,
    isIn: bool = false,
    done: ?*const fn () void = null,

    fn startIn(self: *Fade) void {
        self.timer = .init(1);
        self.isIn = true;
        self.done = null;
    }

    fn startOut(self: *Fade, done: ?*const fn () void) void {
        self.timer = .init(1);
        self.isIn = false;
        self.done = done;
    }

    // 推进淡入淡出，并返回本帧是否由它占用。
    fn update(self: *Fade, delta: f32) bool {
        const timer = if (self.timer) |*value| value else return false;
        if (timer.updateRunning(delta)) return true;

        if (self.isIn) {
            self.timer = null;
        } else {
            if (self.done) |done| done();
            self.startIn();
        }
        return true;
    }

    fn draw(self: *Fade) void {
        const timer = if (self.timer) |*value| value else return;
        camera.push(.window);
        defer camera.pop();

        const percent = timer.progress();
        const alpha = if (self.isIn) 1 - percent else percent;
        zhu.batch.drawRect(.init(.zero, window.size), .{
            .color = .rgba(0, 0, 0, alpha),
        });
    }
};

var currentSceneType: SceneType = .title;
var pendingScene: Scene = .title;
var pendingPortalKey: zon.Portal.Key = undefined;
var fade: Fade = .{};

var isHelp: bool = true;
var isDebug: bool = false;
var world: ecs.World = undefined;
// 场景负责保存应用分配器，并向需要分配内存的模块传递。
var allocator: zhu.Allocator = undefined;

pub fn init(allocator_: zhu.Allocator) void {
    allocator = allocator_;
    world = ecs.World.init(allocator_.raw);
    world.entity = world.createEntity();
    titleScene.init();
    ui.init();
    map.init(&world);
    battleScene.init(allocator_);

    titleScene.enter();
    fade.startIn();
}

fn changeScene(next: Scene) void {
    pendingScene = next;
    fade.startOut(doChangeScene);
}

fn changeMap(portalKey: zon.Portal.Key) void {
    pendingPortalKey = portalKey;
    fade.startOut(doChangeMap);
}

fn doChangeMap() void {
    map.enter(&world, allocator, .{
        .portal = pendingPortalKey,
    });
}

fn doChangeScene() void {
    switch (currentSceneType) {
        .title => titleScene.exit(),
        .world => {},
        .battle => {},
    }
    currentSceneType = std.meta.activeTag(pendingScene);
    switch (pendingScene) {
        .title => titleScene.enter(),
        .world => |entry| enterWorld(entry),
        .battle => battleScene.enter(&world),
    }
}

fn enterWorld(entry: WorldEntry) void {
    ui.reset();
    switch (entry) {
        .start => {
            map.reset(&world);
            map.enter(&world, allocator, .{
                .location = .{
                    .portal = .start,
                    .position = .xy(180, 164),
                    .facing = .down,
                },
            });
            world.add(world.entity, Dialog{
                .lines = zon.dialogues[2].lines,
            });
            world.add(
                world.getIdentity(Player).?,
                Interact.Disabled{},
            );
        },
        .battle => {
            system.story.update(&world);
            camera.directFollow(map.playerPosition(&world));
            camera.roundPosition(null);
        },
        .load => |index| {
            const location = map.load(&world, index) catch
                @panic("load failed");
            map.enter(&world, allocator, .{ .location = location });
        },
        .loadPause => |index| {
            const location = map.load(&world, index) catch
                @panic("load failed");
            map.enter(&world, allocator, .{ .location = location });
            ui.openPause();
        },
    }
    zhu.audio.playMusic("voc/back.ogg");
}

pub fn update(delta: f32) void {
    if (zon.input.released(.help)) isHelp = !isHelp;
    if (zon.input.released(.debug)) isDebug = !isDebug;

    if (zhu.key.held(.LEFT_ALT) and zhu.key.released(.ENTER)) {
        return window.toggleFullScreen();
    }

    if (fade.update(delta)) return;
    switch (currentSceneType) {
        .title => if (titleScene.update(delta)) |req| switch (req) {
            .fadeOut => |done| fade.startOut(done),
            .start => changeScene(.{ .world = .start }),
            .load => |index| changeScene(.{
                .world = .{ .load = index },
            }),
        },
        .world => updateWorld(delta),
        .battle => if (battleScene.update(&world, delta)) |request| {
            switch (request) {
                .world => changeScene(.{ .world = .battle }),
                .title => changeScene(.title),
            }
        },
    }
}

fn updateWorld(delta: f32) void {
    if (ui.update(&world, delta)) |request| {
        switch (request) {
            .block => {},
            .battle => changeScene(.battle),
            .load => |index| changeScene(.{
                .world = .{ .loadPause = index },
            }),
            .save => |index| map.save(&world, index) catch
                @panic("save failed"),
            .title => changeScene(.title),
        }
        return;
    }

    system.update(&world, delta);

    const portals = world.getEvent(component.event.Portal);
    if (portals.len > 0) {
        const portalKey = portals[0].key;
        world.clearEvent(component.event.Portal);
        changeMap(portalKey);
        return;
    }

    if (world.getIdentity(Enemy) != null) {
        changeScene(.battle);
    }
}

pub fn draw() void {
    switch (currentSceneType) {
        .title => titleScene.draw(),
        .world => {
            system.render.draw(&world);

            camera.push(.window);
            ui.draw(&world);
            camera.pop();
        },
        .battle => battleScene.draw(&world),
    }

    fade.draw();

    camera.push(.window);
    defer camera.pop();
    if (isHelp) drawHelpInfo() else if (isDebug) drawDebugInfo();
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关掉
        \\作者：jiangbo4444
    ;

    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.text.draw(text, .xy(10, 5), .{ .color = .green });
}

fn drawDebugInfo() void {
    zhu.text.msdf.begin();
    defer zhu.text.msdf.end();
    zhu.debug.draw(&.{});
}

pub fn deinit() void {
    world.deinit();
    map.deinit(allocator);
    zhu.audio.setMusicState(.stopped);
    battleScene.deinit(allocator);
}
