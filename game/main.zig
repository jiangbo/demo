const std = @import("std");
const gfx = @import("graphics.zig");
const cache = @import("cache.zig");
const context = @import("context.zig");
const window = @import("window.zig");
const animation = @import("animation.zig");

const Player = @import("player.zig").Player;

var background: gfx.Texture = undefined;

fn init() void {
    const allocator = context.allocator;
    cache.init(allocator);

    context.camera = gfx.Camera.init(context.width, context.height);
    context.textureSampler = gfx.Sampler.liner();

    context.batchBuffer = gfx.BatchBuffer.init(allocator) catch unreachable;

    // 加载背景
    background = cache.TextureCache.load("assets/img/background.png").?;

    // 加载角色
    player = Player.init();

    // 加载敌人
    enemy = Enemy.init();
}

const Enemy = struct {
    x: f32 = 400,
    y: f32 = 400,
    leftAnimation: animation.FrameAnimation,
    rightAnimation: animation.FrameAnimation,
    shadow: gfx.Texture,
    faceLeft: bool = true,

    pub fn init() Enemy {
        const leftFmt: []const u8 = "assets/img/enemy_left_{}.png";
        const left = animation.FrameAnimation.load(leftFmt, 6, 50).?;

        const rightFmt = "assets/img/enemy_right_{}.png";
        const right = animation.FrameAnimation.load(rightFmt, 6, 50).?;

        return .{
            .leftAnimation = left,
            .rightAnimation = right,
            .shadow = cache.TextureCache.load("assets/img/shadow_enemy.png").?,
        };
    }

    pub fn update(self: *Enemy, delta: f32) void {
        if (self.faceLeft)
            self.leftAnimation.play(delta)
        else
            self.rightAnimation.play(delta);
    }

    pub fn currentTexture(self: Enemy) gfx.Texture {
        if (self.faceLeft) {
            return self.leftAnimation.currentTexture();
        } else {
            return self.rightAnimation.currentTexture();
        }
    }

    pub fn shadowX(self: Enemy) f32 {
        const w = self.currentTexture().width - self.shadow.width;
        return self.x + w / 2;
    }

    pub fn shadowY(self: Enemy) f32 {
        return self.y + self.currentTexture().height - 25;
    }
};

var player: Player = undefined;
var enemy: Enemy = undefined;

fn frame() void {
    const delta = window.deltaMillisecond();
    player.update(delta);
    enemy.update(delta);

    var renderPass = gfx.CommandEncoder.beginRenderPass(context.clearColor);
    defer renderPass.submit();

    var single = gfx.TextureSingle.begin(renderPass);

    single.draw(0, 0, background);

    single.draw(enemy.shadowX(), enemy.shadowY(), enemy.shadow);
    single.draw(enemy.x, enemy.y, enemy.currentTexture());

    single.draw(player.shadowX(), player.shadowY(), player.shadow);
    single.draw(player.x, player.y, player.currentTexture());
}

fn event(evt: ?*const window.Event) void {
    if (evt) |e| player.processEvent(e);
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
