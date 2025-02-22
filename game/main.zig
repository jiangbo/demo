const std = @import("std");
const gfx = @import("graphics.zig");
const cache = @import("cache.zig");
const context = @import("context.zig");
const window = @import("window.zig");
const animation = @import("animation.zig");

const playerAnimationNumber = 6;

var background: gfx.Texture = undefined;
var playerLeft: animation.FrameAnimation = undefined;
var playerRight: animation.FrameAnimation = undefined;

fn init() void {
    const allocator = context.allocator;
    cache.init(allocator);

    context.camera = gfx.Camera.init(context.width, context.height);
    context.textureSampler = gfx.Sampler.liner();

    context.batchBuffer = gfx.BatchBuffer.init(allocator) catch unreachable;

    // 加载背景
    background = cache.TextureCache.load("assets/img/background.png").?;

    // 加载角色
    const leftFmt: []const u8 = "assets/img/player_left_{}.png";
    playerLeft = animation.FrameAnimation.load(leftFmt, 6, 50).?;

    const rightFmt = "assets/img/player_right_{}.png";
    playerRight = animation.FrameAnimation.load(rightFmt, 6, 50).?;
}

const Vector2 = struct { x: f32 = 0, y: f32 = 0 };

var playerPosition: Vector2 = .{ .x = 500, .y = 500 }; // 角色初始位置
const playerSpeed: f32 = 3; // 角色移动速度

fn frame() void {
    if (moveUp) playerPosition.y -= playerSpeed;
    if (moveDown) playerPosition.y += playerSpeed;
    if (moveLeft) playerPosition.x -= playerSpeed;
    if (moveRight) playerPosition.x += playerSpeed;

    var renderPass = gfx.CommandEncoder.beginRenderPass(context.clearColor);
    defer renderPass.submit();

    var single = gfx.TextureSingle.begin(renderPass);

    single.draw(0, 0, background);

    const delta = window.deltaMillisecond();
    single.draw(playerPosition.x, playerPosition.y, playerRight.currentOrNext(delta));

    // var batch = gfx.TextureBatch.begin(renderPass, playerLeft[playerAnimationIndex]);
    // batch.draw(0, 0);
    // batch.end();
}

var moveUp: bool = false;
var moveDown: bool = false;
var moveLeft: bool = false;
var moveRight: bool = false;

fn event(evt: ?*const window.Event) void {
    if (evt) |e| if (e.type == .KEY_DOWN) switch (e.key_code) {
        .W => moveUp = true,
        .S => moveDown = true,
        .A => moveLeft = true,
        .D => moveRight = true,
        else => {},
    } else if (e.type == .KEY_UP) switch (e.key_code) {
        .W => moveUp = false,
        .S => moveDown = false,
        .A => moveLeft = false,
        .D => moveRight = false,
        else => {},
    };
}

fn deinit() void {
    context.batchBuffer.deinit(context.allocator);
    cache.deinit();
}

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    context.allocator = gpa.allocator();

    context.width = 1280;
    context.height = 720;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    context.rand = prng.random();
    window.run(.{ .init = init, .event = event, .frame = frame, .deinit = deinit });
}
