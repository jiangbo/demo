const std = @import("std");
const window = @import("window.zig");
const gfx = @import("graphics.zig");

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

    menuScene = MenuScene.init();
    gameScene = GameScene.init();
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
    background: gfx.Texture,

    pub fn init() MenuScene {
        std.log.info("menu scene init", .{});

        return .{
            .background = gfx.loadTexture("assets/menu_background.png").?,
        };
    }

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
        gfx.draw(0, 0, self.background);
        window.displayText(2, 2, "menu scene");
    }
};

pub const GameScene = struct {
    idleAtlas: gfx.BoundedTextureAtlas(9),

    pub fn init() GameScene {
        std.log.info("game scene init", .{});
        return .{
            .idleAtlas = .init("assets/peashooter_idle_{}.png"),
        };
    }

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
        gfx.draw(300, 300, self.idleAtlas.textures[0]);
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
