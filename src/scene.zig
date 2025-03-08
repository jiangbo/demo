const std = @import("std");
const window = @import("window.zig");

pub var currentScene: Scene = undefined;

var menuScene: MenuScene = undefined;
var gameScene: GameScene = undefined;
var selectorScene: SelectorScene = undefined;

pub const SceneType = enum { menu, game, selector };
pub const Scene = union(SceneType) {
    menu: *MenuScene,
    game: *GameScene,
    selector: *SelectorScene,

    pub fn enter(self: Scene) void {
        switch (self) {
            inline else => |s| s.enter(),
        }
    }

    pub fn exit(self: Scene) void {
        switch (self) {
            inline else => |s| s.exit(),
        }
    }

    pub fn event(self: Scene, ev: *const window.Event) void {
        switch (self) {
            inline else => |s| s.event(ev),
        }
    }

    pub fn update(self: Scene) void {
        switch (self) {
            inline else => |s| s.update(),
        }
    }

    pub fn render(self: Scene) void {
        switch (self) {
            inline else => |s| s.render(),
        }
    }
};

pub fn init() void {
    std.log.info("scene init", .{});

    menuScene = MenuScene{};
    gameScene = GameScene{};
    selectorScene = SelectorScene{};
    currentScene = Scene{ .menu = &menuScene };

    currentScene.enter();
}

fn changeCurrentScene(sceneType: SceneType) void {
    currentScene.exit();
    currentScene = switch (sceneType) {
        .menu => Scene{ .menu = &menuScene },
        .game => Scene{ .game = &gameScene },
        .selector => Scene{ .selector = &selectorScene },
    };
    currentScene.enter();
}

pub fn deinit() void {
    std.log.info("scene deinit", .{});
}

pub const MenuScene = struct {
    pub fn enter(self: *MenuScene) void {
        std.log.info("menu scene enter", .{});
        _ = self;
    }

    pub fn exit(self: *MenuScene) void {
        std.log.info("menu scene exit", .{});
        _ = self;
    }

    pub fn event(self: *MenuScene, ev: *const window.Event) void {
        std.log.info("menu scene event", .{});

        if (ev.type == .KEY_UP) changeCurrentScene(.game);

        _ = self;
    }

    pub fn update(self: *MenuScene) void {
        std.log.info("menu scene update", .{});
        _ = self;
    }

    pub fn render(self: *MenuScene) void {
        _ = self;

        window.displayText(2, 2, "menu scene");
    }
};

pub const GameScene = struct {
    pub fn enter(self: *GameScene) void {
        std.log.info("game scene enter", .{});
        _ = self;
    }

    pub fn exit(self: *GameScene) void {
        std.log.info("game scene exit", .{});
        _ = self;
    }

    pub fn event(self: *GameScene, ev: *const window.Event) void {
        std.log.info("game scene event", .{});
        _ = self;
        if (ev.type == .KEY_UP) changeCurrentScene(.menu);
    }

    pub fn update(self: *GameScene) void {
        std.log.info("game scene update", .{});
        _ = self;
    }

    pub fn render(self: *GameScene) void {
        _ = self;

        window.displayText(2, 2, "game scene");
    }
};

pub const SelectorScene = struct {
    pub fn enter(self: *SelectorScene) void {
        std.log.info("selector scene enter", .{});
        _ = self;
    }

    pub fn exit(self: *SelectorScene) void {
        std.log.info("selector scene exit", .{});
        _ = self;
    }

    pub fn event(self: *SelectorScene, ev: *const window.Event) void {
        std.log.info("selector scene event", .{});
        _ = self;
        _ = ev;
    }

    pub fn update(self: *SelectorScene) void {
        std.log.info("selector scene update", .{});
        _ = self;
    }

    pub fn render(self: *SelectorScene) void {
        std.log.info("selector scene render", .{});
        _ = self;
    }
};
