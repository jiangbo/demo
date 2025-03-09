const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");

const scene = @import("../scene.zig");
const SelectorScene = @This();

const offsetX = 50;

background: gfx.Texture,

peaShooterBackground: gfx.Texture,
sunFlowerBackground: gfx.Texture,
imageVS: gfx.Texture,
imageTip: gfx.Texture,

image1P: gfx.Texture,
image2P: gfx.Texture,
image1PDesc: gfx.Texture,
image2PDesc: gfx.Texture,
imageGrave: gfx.Texture,

image1PButtonIdle: gfx.Texture,
image2PButtonIdle: gfx.Texture,

animationPeaShooterIdle: gfx.BoundedFrameAnimation(9),
animationSunFlowerIdle: gfx.BoundedFrameAnimation(8),

backgroundOffsetX: f32 = 0,

pub fn init() SelectorScene {
    std.log.info("selector scene init", .{});

    var self: SelectorScene = undefined;
    self.background = gfx.loadTexture("assets/selector_background.png").?;
    self.peaShooterBackground = gfx.loadTexture("assets/peashooter_selector_background.png").?;
    self.sunFlowerBackground = gfx.loadTexture("assets/sunflower_selector_background.png").?;

    self.imageVS = gfx.loadTexture("assets/VS.png").?;
    self.imageTip = gfx.loadTexture("assets/selector_tip.png").?;
    self.image1P = gfx.loadTexture("assets/1P.png").?;
    self.image2P = gfx.loadTexture("assets/2P.png").?;
    self.image1PDesc = gfx.loadTexture("assets/1P_desc.png").?;
    self.image2PDesc = gfx.loadTexture("assets/2P_desc.png").?;
    self.imageGrave = gfx.loadTexture("assets/gravestone.png").?;

    self.image1PButtonIdle = gfx.loadTexture("assets/1P_selector_btn_idle.png").?;
    self.image2PButtonIdle = gfx.loadTexture("assets/2P_selector_btn_idle.png").?;

    self.animationPeaShooterIdle = .init("assets/peashooter_idle_{}.png");
    self.animationSunFlowerIdle = .init("assets/sunflower_idle_{}.png");

    return self;
}

pub fn enter(self: *SelectorScene) void {
    std.log.info("selector scene enter", .{});
    _ = self;
}

pub fn exit(self: *SelectorScene) void {
    std.log.info("selector scene exit", .{});
    _ = self;
}

pub fn event(self: *SelectorScene, ev: *const window.Event) void {
    _ = self;
    _ = ev;
}

pub fn update(self: *SelectorScene) void {
    self.backgroundOffsetX += window.deltaMillisecond() * 0.2;
    if (self.backgroundOffsetX >= self.peaShooterBackground.width)
        self.backgroundOffsetX = 0;
    self.animationPeaShooterIdle.update(window.deltaMillisecond());
    self.animationSunFlowerIdle.update(window.deltaMillisecond());
}

pub fn render(self: *SelectorScene) void {
    self.renderBackground();

    self.renderStatic();

    var x = (window.width / 2 - self.imageGrave.width) / 2 - offsetX;
    const y = self.image1P.height + 70;

    var buttonX = x - self.image1PButtonIdle.width;
    const buttonY = y + (self.imageGrave.height - self.image1PButtonIdle.height) / 2;
    gfx.drawFlipX(buttonX, buttonY, self.image1PButtonIdle, true);

    buttonX = x + self.imageGrave.width;
    gfx.draw(buttonX, buttonY, self.image1PButtonIdle);

    x = window.width / 2 + (window.width / 2 - self.imageGrave.width) / 2 + offsetX;
    buttonX = x - self.image2PButtonIdle.width;
    gfx.drawFlipX(buttonX, buttonY, self.image2PButtonIdle, true);

    buttonX = x + self.imageGrave.width;
    gfx.draw(buttonX, buttonY, self.image2PButtonIdle);

    var w = window.width / 2 - self.animationPeaShooterIdle.atlas.textures[0].width;
    self.animationPlay(scene.player1, w / 2 - offsetX, y + 80, false);

    w = window.width / 2 - self.animationSunFlowerIdle.atlas.textures[0].width;
    self.animationPlay(scene.player2, window.width / 2 + w / 2 + offsetX, y + 80, true);
}

fn renderBackground(self: *SelectorScene) void {
    gfx.draw(0, 0, self.background);

    const width = self.peaShooterBackground.width;
    var texture = if (scene.player2 == .peaShooter)
        self.peaShooterBackground
    else
        self.sunFlowerBackground;
    gfx.draw(self.backgroundOffsetX - width, 0, texture);

    gfx.drawOptions(self.backgroundOffsetX, 0, texture, .{ .sourceRect = .{
        .width = width - self.backgroundOffsetX,
        .height = self.peaShooterBackground.height,
    } });

    texture = if (scene.player1 == .peaShooter)
        self.peaShooterBackground
    else
        self.sunFlowerBackground;

    gfx.drawOptions(window.width - width, 0, texture, .{
        .flipX = true,
        .sourceRect = .{
            .x = self.backgroundOffsetX,
            .width = width - self.backgroundOffsetX,
            .height = self.sunFlowerBackground.height,
        },
    });
    gfx.drawFlipX(window.width - self.backgroundOffsetX, 0, texture, true);
}

fn renderStatic(self: *SelectorScene) void {
    var w = window.width - self.imageVS.width;
    const h = window.height - self.imageVS.height;
    gfx.draw(w / 2, h / 2, self.imageVS);

    w = window.width - self.imageTip.width;
    gfx.draw(w / 2, window.height - 125, self.imageTip);

    w = window.width / 2 - self.image1P.width;
    const pos1PY = 35;
    gfx.draw(w / 2 - offsetX, pos1PY, self.image1P);
    w = window.width / 2 - self.image2P.width;
    gfx.draw(window.width / 2 + w / 2 + offsetX, 35, self.image2P);

    w = window.width / 2 - self.image1PDesc.width;
    gfx.draw(w / 2 - offsetX, window.height - 150, self.image1PDesc);
    w = window.width / 2 - self.image2PDesc.width;
    gfx.draw(window.width / 2 + w / 2 + offsetX, window.height - 150, self.image2PDesc);

    w = window.width / 2 - self.imageGrave.width;
    const posGraveY = pos1PY + self.image1P.height + 35;
    gfx.draw(w / 2 - offsetX, posGraveY, self.imageGrave);
    w = window.width / 2 - self.imageGrave.width;
    gfx.drawFlipX(window.width / 2 + w / 2 + offsetX, posGraveY, self.imageGrave, true);
}

fn animationPlay(self: *SelectorScene, player: scene.PlayerType, x: f32, y: f32, flip: bool) void {
    switch (player) {
        .sunFlower => self.animationSunFlowerIdle.playFlipX(x, y, flip),
        .peaShooter => self.animationPeaShooterIdle.playFlipX(x, y, flip),
    }
}
