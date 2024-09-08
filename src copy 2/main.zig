const std = @import("std");
const win32 = @import("win32");
const d3d = @import("d3d.zig");
const d3dx9 = @import("d3dx9.zig");

const d3d9 = win32.graphics.direct3d9;
const ui = win32.ui.windows_and_messaging;
const failed = win32.zig.FAILED;

// Globals
// var allocator: std.mem.Allocator = undefined;
pub const UNICODE: bool = true;
var device: *d3d9.IDirect3DDevice9 = undefined;

var teapot: *d3dx9.ID3DXMesh = undefined;
var sphere: *d3dx9.ID3DXMesh = undefined;
var BSphere: BoundingSphere = undefined;

const BoundingSphere = struct {
    center: d3dx9.Vec3,
    radius: f32,
};

const Ray = struct {
    origin: d3dx9.Vec3,
    direction: d3dx9.Vec3,
};

// Framework Functions
fn setup() bool {

    // 创建茶壶
    _ = d3dx9.D3DXCreateTeapot(device, &teapot, null);

    //
    // Compute the bounding sphere.
    //
    var buffer: *d3dx9.Vec3 = undefined;
    _ = teapot.ID3DXBaseMesh_LockVertexBuffer(0, @ptrCast(&buffer));

    _ = d3dx9.D3DXComputeBoundingSphere(
        buffer,
        teapot.ID3DXBaseMesh_GetNumVertices(),
        d3dx9.D3DXGetFVFVertexSize(teapot.ID3DXBaseMesh_GetFVF()),
        &BSphere.center,
        &BSphere.radius,
    );

    _ = teapot.ID3DXBaseMesh_UnlockVertexBuffer();

    //
    // Build a sphere mesh that describes the teapot's bounding sphere.
    //
    _ = d3dx9.D3DXCreateSphere(device, BSphere.radius, 20, 20, &sphere, null);

    // 设置方向光
    var light = std.mem.zeroes(d3d9.D3DLIGHT9);
    light.Type = d3d9.D3DLIGHT_DIRECTIONAL;
    light.Ambient = .{ .r = 0.4, .g = 0.4, .b = 0.4, .a = 0.4 };
    light.Diffuse = .{ .r = 1, .g = 1, .b = 1, .a = 1 };
    light.Specular = .{ .r = 0.6, .g = 0.6, .b = 0.6, .a = 0.6 };
    light.Direction = .{ .x = 0.707, .y = -0.707, .z = 0.707 };
    _ = device.IDirect3DDevice9_SetLight(0, &light);
    _ = device.IDirect3DDevice9_LightEnable(0, 1);

    // 打开镜面光
    _ = device.IDirect3DDevice9_SetRenderState(.NORMALIZENORMALS, 1);
    _ = device.IDirect3DDevice9_SetRenderState(.SPECULARENABLE, 0);

    // 设置视图矩阵
    const position = .{ .z = -10 };
    var view: win32.graphics.direct3d.D3DMATRIX = undefined;
    _ = d3dx9.D3DXMatrixLookAtLH(&view, &position, &.{}, &.{ .y = 1.0 });
    _ = device.IDirect3DDevice9_SetTransform(d3d9.D3DTS_VIEW, &view);

    // 设置投影矩阵
    var p: win32.graphics.direct3d.D3DMATRIX = undefined;
    const w = @as(f32, @floatFromInt(WIDTH));
    const h = @as(f32, @floatFromInt(HEIGHT));
    const fov = std.math.pi / 4.0;
    _ = d3dx9.D3DXMatrixPerspectiveFovLH(&p, fov, w / h, 1.0, 1000.0);
    _ = device.IDirect3DDevice9_SetTransform(.PROJECTION, &p);

    return true;
}

fn cleanup() void {}

var r: f32 = 0.0;
var v: f32 = 1.0;
var angle: f32 = 0.0;
var world: win32.graphics.direct3d.D3DMATRIX = undefined;

fn display(delta: f32) bool {
    if (d3d.point) |point| {
        const x: f32 = @floatFromInt(point & 0xffff);
        const y: f32 = @floatFromInt((point >> 16) & 0xffff);
        d3d.point = null;

        // compute the ray in view space given the clicked screen point
        var ray = calcPickingRay(x, y);

        // transform the ray to world space
        var view: win32.graphics.direct3d.D3DMATRIX = undefined;
        _ = device.IDirect3DDevice9_GetTransform(.VIEW, &view);

        var viewInverse: win32.graphics.direct3d.D3DMATRIX = undefined;
        _ = d3dx9.D3DXMatrixInverse(&viewInverse, null, &view);

        transformRay(&ray, &viewInverse);

        // test for a hit
        if (raySphereIntTest(&ray, &BSphere))
            std.log.debug("Hit", .{});
    }

    //
    // Update: Update Teapot.
    //
    _ = d3dx9.D3DXMatrixTranslation(&world, @cos(angle) * r, @sin(angle) * r, 10.0);

    // transfrom the bounding sphere to match the teapots position in the
    // world.
    BSphere.center = .{ .x = @cos(angle) * r, .y = @sin(angle) * r, .z = 10 };

    r += v * delta;

    if (r >= 8.0)
        v = -v; // reverse direction

    if (r <= 0.0)
        v = -v; // reverse direction
    angle += 1.0 * std.math.pi * delta;
    if (angle >= std.math.pi * 2.0)
        angle = 0.0;

    const flags = win32.system.system_services.D3DCLEAR_TARGET |
        win32.system.system_services.D3DCLEAR_ZBUFFER;

    _ = device.IDirect3DDevice9_Clear(0, null, flags, 0xffff00ff, 1, 0);
    _ = device.IDirect3DDevice9_BeginScene();

    // draw teapot
    _ = device.IDirect3DDevice9_SetTransform(.WORLD, &world);
    _ = device.IDirect3DDevice9_SetMaterial(&d3d.Material.yellow);
    _ = teapot.ID3DXBaseMesh_DrawSubset(0);

    // Render the bounding sphere with alpha blending so we can see
    // through it.
    _ = device.IDirect3DDevice9_SetRenderState(.ALPHABLENDENABLE, 1);
    var state = @intFromEnum(d3d9.D3DBLEND_SRCALPHA);
    _ = device.IDirect3DDevice9_SetRenderState(.SRCBLEND, state);
    state = @intFromEnum(d3d9.D3DBLEND_INVSRCALPHA);
    _ = device.IDirect3DDevice9_SetRenderState(.DESTBLEND, state);

    var red = d3d.Material.black;
    red.Diffuse.a = 0.25; // 25% opacity
    _ = device.IDirect3DDevice9_SetMaterial(&red);
    _ = sphere.ID3DXBaseMesh_DrawSubset(0);

    _ = device.IDirect3DDevice9_SetRenderState(.ALPHABLENDENABLE, 0);

    _ = device.IDirect3DDevice9_EndScene();
    _ = device.IDirect3DDevice9_Present(null, null, null, null);

    return true;
}

const WIDTH: i32 = 640;
const HEIGHT: i32 = 480;

// main
pub fn main() void {
    device = d3d.initD3D(WIDTH, HEIGHT);

    if (!setup()) @panic("Setup() - FAILED");

    d3d.enterMsgLoop(display);

    cleanup();
    _ = device.IUnknown_Release();
}

fn calcPickingRay(x: f32, y: f32) Ray {
    var px: f32 = 0.0;
    var py: f32 = 0.0;

    var vp: d3d9.D3DVIEWPORT9 = undefined;
    _ = device.IDirect3DDevice9_GetViewport(&vp);

    var proj: win32.graphics.direct3d.D3DMATRIX = undefined;
    _ = device.IDirect3DDevice9_GetTransform(.PROJECTION, &proj);

    const w: f32 = @as(f32, @floatFromInt(vp.Width));
    const h: f32 = @as(f32, @floatFromInt(vp.Height));
    px = (((2.0 * x) / w) - 1.0) / proj.Anonymous.Anonymous._11;
    py = (((-2.0 * y) / h) + 1.0) / proj.Anonymous.Anonymous._22;

    return Ray{
        .origin = .{ .x = 0, .y = 0, .z = 0 },
        .direction = .{ .x = px, .y = py, .z = 1.0 },
    };
}

fn transformRay(ray: *Ray, T: *win32.graphics.direct3d.D3DMATRIX) void {
    // transform the ray's origin, w = 1.

    _ = d3dx9.D3DXVec3TransformCoord(&ray.origin, &ray.origin, T);

    // transform the ray's direction, w = 0.
    _ = d3dx9.D3DXVec3TransformNormal(&ray.direction, &ray.direction, T);

    // normalize the direction
    ray.direction = ray.direction.normalize();
}

fn raySphereIntTest(ray: *Ray, s: *BoundingSphere) bool {
    const t = ray.origin.sub(s.center);
    const b = 2.0 * ray.direction.dot(t);

    const c = t.dot(t) - (s.radius * s.radius);

    // find the discriminant
    var discriminant = (b * b) - (4.0 * c);

    // test for imaginary number
    if (discriminant < 0.0)
        return false;

    discriminant = @sqrt(discriminant);

    const s0 = (-b + discriminant) / 2.0;
    const s1 = (-b - discriminant) / 2.0;

    // if a solution is >= 0, then we intersected the sphere
    if (s0 >= 0.0 or s1 >= 0.0)
        return true;

    return false;
}
