const std = @import("std");
const gfx = @import("graphics.zig");
const cache = @import("cache.zig");
const context = @import("context.zig");
const window = @import("window.zig");

const playerAnimationNumber = 6;

var background: gfx.Texture = undefined;
var playerLeft: [playerAnimationNumber]gfx.Texture = undefined;
var playerRight: [playerAnimationNumber]gfx.Texture = undefined;

fn init() void {
    const allocator = context.allocator;
    cache.init(allocator);

    context.camera = gfx.Camera.init(context.width, context.height);
    context.textureSampler = gfx.Sampler.liner();

    context.batchBuffer = gfx.BatchBuffer.init(allocator) catch unreachable;

    // 加载背景
    background = cache.TextureCache.load("assets/img/background.png").?;

    // 加载角色
    var nameBuffer: [64]u8 = undefined;
    for (0..playerAnimationNumber) |index| {
        playerLeft[index] = loadTexture(&nameBuffer, "left", index).?;
    }
    for (0..playerAnimationNumber) |index| {
        playerRight[index] = loadTexture(&nameBuffer, "right", index).?;
    }
}

const pathFmt = "assets/img/player_{s}_{}.png";
fn loadTexture(buffer: []u8, direction: []const u8, index: usize) ?gfx.Texture {
    const path = std.fmt.bufPrintZ(buffer, pathFmt, .{ direction, index });
    return cache.TextureCache.load(path catch unreachable).?;
}

var frameCounter: usize = 0;
var playerAnimationIndex: usize = 0;

fn frame() void {
    frameCounter += 1;
    if (frameCounter % 5 == 0) playerAnimationIndex += 1;

    playerAnimationIndex %= playerAnimationNumber;

    var renderPass = gfx.CommandEncoder.beginRenderPass(context.clearColor);
    defer renderPass.submit();

    var single = gfx.TextureSingle.begin(renderPass);

    single.draw(0, 0, background);
    single.draw(100, 100, playerLeft[playerAnimationIndex]);
}

fn event(evt: ?*const window.Event) void {
    _ = evt;
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
