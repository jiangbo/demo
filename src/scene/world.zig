const std = @import("std");

const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const camera = @import("../camera.zig");

pub const Player = @import("Player.zig");
pub const map = @import("map.zig");
const statusPopup = @import("statusPopup.zig");
const scene = @import("../scene.zig");

const Dialog = struct {
    var background: gfx.Texture = undefined;
    face: gfx.Texture = undefined,
    left: bool = true,
    npc: *map.NPC = undefined,
    name: []const u8 = &.{},
    content: []const u8 = &.{},
};

const Tip = struct {
    var background: gfx.Texture = undefined;
};

pub const Item = struct {
    name: []const u8,
    count: u32 = 0,
    texture: gfx.Texture,
    tip: []const u8,
};
pub var items: [10]Item = undefined;
pub var skills: [10]Item = undefined;

pub var players: [3]Player = undefined;
pub var currentPlayer: *Player = &players[0];

var dialog: ?Dialog = null;
var face: gfx.Texture = undefined;

var tip: ?Tip = null;
var talkTexture: gfx.Texture = undefined;

pub var mouseTarget: ?gfx.Vector = null;
var targetTexture: gfx.Texture = undefined;
var moveTimer: window.Timer = .init(0.4);
var moveDisplay: bool = true;

pub fn init() void {
    players[0] = Player.init(0);
    players[1] = Player.init(1);
    players[2] = Player.init(2);

    Dialog.background = gfx.loadTexture("assets/msg.png", .init(790, 163));
    face = gfx.loadTexture("assets/face1_1.png", .init(307, 355));

    Tip.background = gfx.loadTexture("assets/msgtip.png", .init(291, 42));
    targetTexture = gfx.loadTexture("assets/move_flag.png", .init(33, 37));

    talkTexture = gfx.loadTexture("assets/mc_2.png", .init(30, 30));

    statusPopup.init();

    map.init();

    initItems();
    initSkills();
}

fn initItems() void {
    for (&items) |*item| item.count = 0;

    items[0] = .{
        .name = "红药水",
        .texture = gfx.loadTexture("assets/item/item1.png", .init(66, 66)),
        .tip = "恢复少量 HP",
        .count = 2,
    };

    items[1] = .{
        .name = "蓝药水",
        .texture = gfx.loadTexture("assets/item/item2.png", .init(66, 66)),
        .tip = "恢复少量 MP",
        .count = 3,
    };

    items[2] = .{
        .name = "短剑",
        .texture = gfx.loadTexture("assets/item/item3.png", .init(66, 66)),
        .tip = "一把钢制短剑",
        .count = 2,
    };
}

fn initSkills() void {
    for (&skills) |*skill| skill.count = 0;

    skills[0] = .{
        .name = "治疗术",
        .texture = gfx.loadTexture("assets/item/skill1.png", .init(66, 66)),
        .tip = "恢复少量 HP",
        .count = 20,
    };

    skills[1] = .{
        .name = "黑洞漩涡",
        .texture = gfx.loadTexture("assets/item/skill2.png", .init(66, 66)),
        .tip = "攻击型技能，将敌人吸入漩涡",
        .count = 20,
    };
}

pub fn enter() void {
    window.playMusic("assets/1.ogg");
}

pub fn exit() void {
    window.stopMusic();
}

pub fn update(delta: f32) void {
    const confirm = window.isAnyKeyRelease(&.{ .SPACE, .ENTER }) or
        window.isButtonRelease(.LEFT);

    if (dialog) |*d| {
        if (confirm) {
            if (d.left) d.left = false else dialog = null;
        }
        return;
    }

    if (tip) |_| {
        if (confirm) tip = null;
        return;
    }

    if (statusPopup.display) return statusPopup.update(delta);

    if (!statusPopup.display and (window.isAnyKeyRelease(&.{ .ESCAPE, .Q, .E }))) {
        statusPopup.display = true;
    }

    if (window.isButtonRelease(.LEFT)) {
        mouseTarget = camera.rect.min.add(window.mousePosition);
    }

    if (mouseTarget != null) {
        if (moveTimer.isFinishedAfterUpdate(delta)) {
            moveDisplay = !moveDisplay;
            moveTimer.reset();
        }
    }

    currentPlayer.update(delta);

    for (map.npcSlice()) |*npc| {
        const contains = npc.area.contains(Player.position);
        if (contains) {
            if (npc.keyTrigger) {
                if (window.isAnyKeyRelease(&.{ .SPACE, .ENTER }))
                    npc.action();
            } else npc.action();
        }

        if (npc.texture != null) {
            const area = npc.area.move(camera.rect.min.neg());
            if (area.contains(window.mousePosition)) {
                scene.cursor = talkTexture;
                if (window.isButtonRelease(.LEFT) and contains) {
                    npc.action();
                }
            }
        }
        map.updateNpc(npc, delta);
    }
}

pub fn render() void {
    map.drawBackground();

    var playerNotDraw: bool = true;
    for (map.npcSlice()) |npc| {
        if (npc.position.y > Player.position.y and playerNotDraw) {
            currentPlayer.render();
            playerNotDraw = false;
        }

        const npcPosition = npc.position.sub(.init(120, 220));

        if (npc.animation != null and !npc.animation.?.finished()) {
            camera.draw(npc.animation.?.currentTexture(), npcPosition);
        } else if (npc.texture) |texture| {
            camera.draw(texture, npcPosition);
        }
    }

    if (playerNotDraw) currentPlayer.render();

    if (mouseTarget) |target| blk: {
        if (!moveDisplay) break :blk;
        const size = targetTexture.size();
        camera.draw(targetTexture, target.sub(.init(size.x / 2, size.y)));
    }

    map.drawForeground();
    renderPopup();

    window.showFrameRate();
}

fn renderPopup() void {
    camera.lookAt(.zero);
    if (dialog) |d| {
        camera.draw(Dialog.background, .init(0, 415));
        if (d.left) {
            camera.drawText(
                \\主角夏山如碧，绿树成荫，总会令人怡然自乐。
                \\此地山清水秀，我十分喜爱。我们便约好了，
                \\闲暇时，便来此地，彻茶共饮。
            , .init(305, 455));
            camera.draw(d.face, .init(0, 245));
        } else {
            camera.draw(d.npc.face.?, .init(486, 245));
        }
    }

    if (tip) |_| {
        camera.draw(Tip.background, .init(251, 200));
    }
    statusPopup.render();
    camera.lookAt(Player.position);
}

pub fn showDialog(npc: *map.NPC) void {
    dialog = Dialog{ .face = face, .npc = npc };
}

pub fn showTip() void {
    tip = Tip{};
}
