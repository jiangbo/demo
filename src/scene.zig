const std = @import("std");
const zhu = @import("zhu");
const ecs = @import("ecs");

const window = zhu.window;
const camera = zhu.camera;

const title = @import("ui/title.zig");
const battle = @import("battle/battle.zig");
const component = @import("component.zig");
const map = @import("map.zig");
const system = @import("system/system.zig");
const ui = @import("ui/ui.zig");
const zon = @import("zon.zig");

const Dialog = component.dialog.Dialog;
const Interact = component.Interact;
const Player = component.actor.Player;
const Portal = component.map.Portal;
const Request = component.event.Request;

const Scene = enum { title, world, battle };

const WorldEntry = union(enum) { start, battle, load: u8 };

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
        const timer = if (self.timer) |*v| v else return false;
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
        const timer = if (self.timer) |*v| v else return;
        camera.push(.window);
        defer camera.pop();

        const percent = timer.progress();
        const alpha = if (self.isIn) 1 - percent else percent;
        zhu.batch.drawRect(.init(.zero, window.size), .{
            .color = .rgba(0, 0, 0, alpha),
        });
    }
};

var current: Scene = .title;
var pending: Scene = .title;
var entry: WorldEntry = undefined;
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
    title.init();
    ui.init();
    map.init(&world);
    battle.init(allocator_);

    title.enter();
    fade.startIn();
}

fn changeScene(next: Scene) void {
    pending = next;
    fade.startOut(doChangeScene);
}

fn changeWorld(next: WorldEntry) void {
    entry = next;
    changeScene(.world);
}

fn doChangeMap() void {
    const entity = world.getIdentity(Portal).?;
    const portal = world.get(entity, Portal).?;
    map.enter(&world, allocator, .{
        .portal = zon.Portal.get(portal.key).target,
    });
}

fn doChangeScene() void {
    switch (current) {
        .title => title.exit(),
        .world => {},
        .battle => {},
    }
    current = pending;
    switch (current) {
        .title => title.enter(),
        .world => enterWorld(),
        .battle => battle.enter(&world),
    }
}

fn enterWorld() void {
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
    switch (current) {
        .title => if (title.update(delta)) |req| switch (req) {
            .fadeOut => |done| fade.startOut(done),
            .start => changeWorld(.start),
            .load => |index| changeWorld(.{ .load = index }),
        },
        .world => updateWorld(delta),
        .battle => if (battle.update(&world, delta)) |request| {
            switch (request) {
                .world => changeWorld(.battle),
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
            .load => |index| changeWorld(.{ .load = index }),
            .save => |index| map.save(&world, index) catch
                @panic("save failed"),
            .title => changeScene(.title),
        }
        return;
    }

    system.update(&world, delta);

    for (world.getEvent(Request)) |request| {
        switch (request) {
            .map => fade.startOut(doChangeMap),
            .battle => changeScene(.battle),
        }
        break;
    }
    world.clearEvent(Request);
}

pub fn draw() void {
    switch (current) {
        .title => title.draw(),
        .world => {
            system.render.draw(&world);
            ui.draw(&world);
        },
        .battle => battle.draw(&world),
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
    battle.deinit(allocator);
}
