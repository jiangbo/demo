const std = @import("std");
const window = @import("../window.zig");
const gfx = @import("../graphics.zig");
const audio = @import("zaudio");

const scene = @import("../scene.zig");

var peaBreakSound: [3]*audio.Sound = undefined;
var peaShootSound: [2]*audio.Sound = undefined;
var peaShootExSound: *audio.Sound = undefined;

pub fn init() void {
    peaBreakSound[0] = scene.audioEngine.createSoundFromFile( //
        "assets/pea_break_1.mp3", .{}) catch unreachable;
    peaBreakSound[1] = scene.audioEngine.createSoundFromFile( //
        "assets/pea_break_2.mp3", .{}) catch unreachable;
    peaBreakSound[2] = scene.audioEngine.createSoundFromFile( //
        "assets/pea_break_3.mp3", .{}) catch unreachable;

    peaShootSound[0] = scene.audioEngine.createSoundFromFile( //
        "assets/pea_shoot_1.mp3", .{}) catch unreachable;

    peaShootSound[1] = scene.audioEngine.createSoundFromFile( //
        "assets/pea_shoot_2.mp3", .{}) catch unreachable;

    peaShootExSound = scene.audioEngine.createSoundFromFile( //
        "assets/pea_shoot_ex.mp3", .{}) catch unreachable;
}

pub fn deinit() void {
    for (peaBreakSound) |sound| sound.destroy();
    for (peaShootSound) |sound| sound.destroy();
    peaShootExSound.destroy();
}

pub const Vector = struct {
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,

    pub fn add(a: Vector, b: Vector) Vector {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn scale(a: Vector, b: f32) Vector {
        return .{ .x = a.x * b, .y = a.y * b, .z = a.z * b };
    }
};

pub const Bullet = struct {
    size: Vector,
    position: Vector,
    velocity: Vector,
    damage: f32,
    dead: bool = false,
    collide: bool = false,
    p1: bool = true,

    type: BulletType = .pea,
    animationBreak: gfx.FrameAnimation,

    texture: gfx.Texture = undefined,

    const peaSpeed: f32 = 0.75;
    const peaSpeedEx: f32 = 1.5;

    pub const BulletType = enum { pea, peaEx, sun };

    pub fn init(bulletType: BulletType) Bullet {
        var self = switch (bulletType) {
            .pea => initPeaBullet(),
            .sun => initSunBullet(),
            else => unreachable,
        };

        self.size = .{ .x = self.texture.width, .y = self.texture.height };

        return self;
    }

    fn initPeaBullet() Bullet {
        var self: Bullet = undefined;
        self.texture = gfx.loadTexture("assets/pea.png").?;
        self.type = .pea;
        self.animationBreak = .load("assets/pea_break_{}.png", 3);
        self.animationBreak.loop = false;
        self.damage = 10;
        self.velocity = .{ .x = peaSpeed };

        return self;
    }

    fn initPeaBulletEx() Bullet {
        var self: Bullet = undefined;
        self.texture = gfx.loadTexture("assets/pea.png").?;
        self.type = .pea;
        self.animationBreak = .load("assets/pea_break_{}.png", 3);
        self.animationBreak.loop = false;
        self.damage = 10;
        self.velocity = .{ .x = peaSpeedEx };
    }

    fn initSunBullet() Bullet {
        var self: Bullet = undefined;
        self.texture = gfx.loadTexture("assets/sun_1.png").?;
        self.type = .sun;

        return self;
    }

    pub fn playShootSound(self: *Bullet) void {
        if (self.type == .pea) {
            const i = window.rand.uintLessThanBiased(u32, peaShootSound.len);
            peaShootSound[i].start() catch unreachable;
        }
    }

    pub fn playShootExSound() void {
        peaShootExSound.start() catch unreachable;
    }

    pub fn update(self: *Bullet, delta: f32) void {
        const position = self.position.add(self.velocity.scale(delta));

        if (self.collide) {
            self.animationBreak.update(delta);
            if (self.animationBreak.done) self.dead = true;
            return;
        }

        if (outWindow(position, self.size)) self.dead = true;

        self.position = position;
    }

    pub fn collidePlayer(self: *Bullet) void {
        if (self.type == .pea) {
            const i = window.rand.uintLessThanBiased(u32, peaBreakSound.len);
            peaBreakSound[i].start() catch unreachable;
        } else {}

        self.collide = true;
        self.velocity = .{};
    }

    fn outWindow(position: Vector, size: Vector) bool {
        if (position.x + size.x < 0 or position.x > window.width) return true;
        if (position.y + size.y < 0 or position.y > window.height) return true;
        return false;
    }

    pub fn render(self: *Bullet) void {
        if (self.collide) {
            self.animationBreak.play(self.position.x, self.position.y);
        } else {
            gfx.draw(self.position.x, self.position.y, self.texture);
        }
    }
};
