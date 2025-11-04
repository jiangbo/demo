const std = @import("std");
const zhu = @import("zhu");

const window = zhu.window;
const gfx = zhu.gfx;
const camera = zhu.camera;
const ecs = zhu.ecs;

const map = @import("map.zig");
const player = @import("player.zig");
const monster = @import("monster.zig");
const hud = @import("hud.zig");
const battle = @import("battle.zig");
const components = @import("components.zig");

const Player = components.Player;
const Position = components.Position;
const TilePosition = components.TilePosition;
const WantToMove = components.WantToMove;

var isHelp = false;
var isDebug = false;
const scale = 1;

pub fn init() void {
    ecs.init(window.allocator);

    window.initFont(.{
        .font = @import("zon/font.zon"),
        .texture = gfx.loadTexture("assets/font.png", .init(960, 960)),
    });

    camera.frameStats(true);
    camera.init(5000);
    camera.scale = .init(scale, scale);

    hud.init();
    map.init();
    player.init();
    cameraFollow();
    monster.init();
}

pub fn update(delta: f32) void {
    if (window.isKeyRelease(.H)) isHelp = !isHelp;
    if (window.isKeyRelease(.X)) isDebug = !isDebug;

    if (window.isKeyDown(.LEFT_ALT) and window.isKeyRelease(.ENTER)) {
        return window.toggleFullScreen();
    }

    const speed: f32 = std.math.round(100 * delta) / scale;
    if (window.isKeyDown(.UP)) camera.position.y -= speed;
    if (window.isKeyDown(.DOWN)) camera.position.y += speed;
    if (window.isKeyDown(.LEFT)) camera.position.x -= speed;
    if (window.isKeyDown(.RIGHT)) camera.position.x += speed;

    player.move();
    battle.checkPlayerAttack();
    monster.move();
    map.update(delta);

    cameraFollow();
    sceneCall("update", .{delta});
}

pub fn cameraFollow() void {
    const playerEntity = ecs.w.getIdentityEntity(Player).?;
    if (!ecs.w.has(playerEntity, WantToMove)) return;

    const position = ecs.w.get(playerEntity, Position).?;

    const scaleSize = window.logicSize.div(camera.scale);
    const half = scaleSize.scale(0.5);
    const max = map.size.sub(scaleSize).max(.zero);
    camera.position = position.sub(half).clamp(.zero, max);
}

pub fn draw() void {
    camera.beginDraw(.{});
    defer camera.endDraw();

    window.keepAspectRatio();
    sceneCall("draw", .{});
    map.draw();

    var view = ecs.w.view(.{ gfx.Texture, Position });
    while (view.next()) |entity| {
        const texture = view.get(entity, gfx.Texture);
        const position = view.get(entity, Position);
        camera.draw(texture, position);
    }

    hud.draw();

    if (isHelp) drawHelpInfo() else if (isDebug) drawDebugInfo();
}

fn drawHelpInfo() void {
    const text =
        \\按键说明：
        \\上：W，下：S，左：A，右：D
        \\确定：F，取消：Q，菜单：E
        \\帮助：H  按一次打开，再按一次关掉
    ;
    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    camera.drawColorText(text, .init(10, 5), .green);
}

var debutTextCount: u32 = 0;
fn drawDebugInfo() void {
    var buffer: [1024]u8 = undefined;
    const format =
        \\后端：{s}
        \\帧率：{}
        \\帧时：{d:.2}
        \\用时：{d:.2}
        \\显存：{}
        \\常量：{}
        \\绘制：{}
        \\图片：{}
        \\文字：{}
        \\内存：{}
        \\鼠标：{d:.2}，{d:.2}
        \\相机：{d:.2}，{d:.2}
    ;

    const stats = camera.queryFrameStats();
    const text = zhu.format(&buffer, format, .{
        @tagName(camera.queryBackend()),
        window.frameRate,
        window.frameDeltaPerSecond,
        window.usedDeltaPerSecond,
        stats.size_append_buffer + stats.size_update_buffer,
        stats.size_apply_uniforms,
        stats.num_draw,
        camera.imageDrawCount(),
        // Debug 信息本身的次数也应该统计进去
        camera.textDrawCount() + debutTextCount,
        window.countingAllocator.used,
        window.mousePosition.x,
        window.mousePosition.y,
        camera.position.x,
        camera.position.y,
    });

    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();
    var count: u32 = 0;
    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') continue;
        count += 1;
    }
    debutTextCount = count;

    camera.drawColorText(text, .init(10, 5), .green);
}

pub fn deinit() void {
    sceneCall("deinit", .{});
    ecs.deinit();
}

fn sceneCall(comptime function: []const u8, args: anytype) void {
    _ = function;
    _ = args;
}
