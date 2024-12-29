const std = @import("std");
const win32 = @import("win32");
const d3dx9 = @import("d3dx9.zig");
const gfx = @import("gfx.zig");

const d3d9 = win32.graphics.direct3d9;
const ui = win32.ui.windows_and_messaging;
const win32Check = gfx.win32Check;

pub const ObjectStatus = enum { active, dying, dead };

pub const Object = struct {
    name: []const u8,

    position: win32.graphics.direct3d.D3DVECTOR = .{ .x = 0, .y = 0, .z = 0 },
    velocity: win32.graphics.direct3d.D3DVECTOR = .{ .x = 0, .y = 0, .z = 0 },
    rotation: f32 = 0,
    speed: f32 = 0,

    status: ObjectStatus = .active,
    sprite: Sprite = undefined,
    maxSpeed: f32,

    pub fn initSprite(self: *Object, device: *gfx.GraphicsDevice, name: d3dx9.LPCTSTR) void {
        self.sprite = Sprite.init(device, name);
    }

    pub fn update(self: *Object, gameTime: f32) void {
        if (self.status != .active) return;
        self.position.x += self.velocity.x * gameTime;
        self.position.y += self.velocity.y * gameTime;
    }

    pub fn draw(self: *Object, gameTime: f32) void {
        self.sprite.draw(gameTime, self.position);
    }

    pub fn setSpeed(self: *Object, speed: f32) void {
        self.speed = @min(speed, self.maxSpeed);
        self.velocity.x = self.speed * @cos(self.rotation);
        self.velocity.y = self.speed * @sin(self.rotation);
    }

    pub fn deinit(self: *Object) void {
        self.sprite.deinit();
    }
};

pub const Sprite = struct {
    texture: *d3d9.IDirect3DTexture9,
    sprite: *d3dx9.ID3DXSprite,

    color: u32 = 0xffffffff,
    initialised: bool,

    pub fn init(device: *gfx.GraphicsDevice, name: d3dx9.LPCTSTR) Sprite {
        var texture: *d3d9.IDirect3DTexture9 = undefined;
        win32Check(d3dx9.D3DXCreateTextureFromFileW(device.device, name, &texture));

        // win32Check(d3dx9.D3DXCreateTextureFromFileExW(device.device, name, //
        //     d, d, d, 0, .UNKNOWN, .MANAGED, d, d, 0, 0, null, &texture));

        var sprite: *d3dx9.ID3DXSprite = undefined;
        win32Check(d3dx9.D3DXCreateSprite(device.device, &sprite));
        return .{ .texture = texture, .sprite = sprite, .initialised = true };
    }

    pub fn draw(self: *Sprite, gameTime: f32, position: win32.graphics.direct3d.D3DVECTOR) void {
        _ = gameTime;

        if (!self.initialised) return;
        win32Check(self.sprite.Begin(d3dx9.D3DXSPRITE_ALPHABLEND));
        win32Check(self.sprite.Draw(self.texture, null, null, &position, self.color));
        win32Check(self.sprite.End());
    }

    pub fn deinit(self: *Sprite) void {
        _ = self.texture.IUnknown.Release();
        _ = self.sprite.IUnknown.Release();
    }
};
