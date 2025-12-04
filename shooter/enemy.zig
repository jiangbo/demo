const std = @import("std");
const zhu = @import("zhu");

const gfx = zhu.gfx;
const window = zhu.window;
const camera = zhu.camera;

const Enemy = struct {
    position: gfx.Vector, // 敌机的位置
};

const SPEED = 200;

var texture: gfx.Texture = undefined; // 敌机的纹理
var size: gfx.Vector = undefined; // 敌机的大小

var enemies: std.ArrayList(Enemy) = .empty;
var spawnTimer: window.Timer = .init(1); // 生成敌机的定时器

pub fn init() void {
    texture = gfx.loadTexture("assets/image/insect-2.png", .init(182, 160));
    size = texture.size().scale(0.25);
}

pub fn update(delta: f32) void {
    if (spawnTimer.isFinishedAfterUpdate(delta)) { // 每秒生成一个
        spawnTimer.reset();
        spawnEnemy();
    }

    for (enemies.items) |*enemy| {
        enemy.position.y += SPEED * delta; // 敌机向下移动
    }
}

pub fn spawnEnemy() void {
    // 在 X 轴上随机生成敌机，Y 固定。
    const x = zhu.randomF32(0, window.logicSize.x - size.x);
    enemies.append(window.allocator, .{
        .position = .init(x, -size.y),
    }) catch unreachable;
}

pub fn draw() void {
    for (enemies.items) |enemy| {
        camera.drawOption(texture, enemy.position, .{ .size = size });
    }
}

pub fn deinit() void {
    enemies.deinit(window.allocator);
}
