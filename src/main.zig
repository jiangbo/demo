const std = @import("std");

const window = @import("window.zig");

pub fn init() void {}

pub fn event(ev: *const window.Event) void {
    _ = ev;
}

pub fn update() void {}

pub fn render() void {}

pub fn deinit() void {}

var allocator: std.mem.Allocator = undefined;

pub fn main() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    allocator = gpa.allocator();
    window.width = 1280;
    window.height = 720;

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    window.rand = prng.random();

    window.run(.{
        .title = "空洞武士",
        .init = init,
        .event = event,
        .update = update,
        .render = render,
        .deinit = deinit,
    });
}
