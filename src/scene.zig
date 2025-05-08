const std = @import("std");

const window = @import("window.zig");
const gfx = @import("graphics.zig");

const titleScene = @import("scene/title.zig");
const worldScene = @import("scene/world.zig");

const SceneType = enum { title, world };

var currentSceneType: SceneType = .title;

pub fn init() void {
    titleScene.init();
    // worldScene.init();
}

pub fn update(delta: f32) void {
    switch (currentSceneType) {
        .title => titleScene.update(delta),
        .world => worldScene.update(delta),
    }
}

pub fn render() void {
    switch (currentSceneType) {
        .title => titleScene.render(),
        .world => worldScene.render(),
    }
}

// fn sceneCall(comptime function: []const u8, args: anytype) void {
//     switch (currentSceneType) {
//         .title => @call(.auto, @field(titleScene, function), args),
//         .world => @call(.auto, @field(worldScene, function), args),
//     }
// }
