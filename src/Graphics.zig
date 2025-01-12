const std = @import("std");
const win32 = @import("win32");
const Direct3D = @import("Direct3D.zig");
const Model = @import("Model.zig");
const Shader = @import("Shader.zig");
const Camera = @import("Camera.zig");
const Texture = @import("Texture.zig");

pub const WIDTH: u16 = 800;
pub const HEIGHT: u16 = 600;

direct3D: Direct3D,
// model: Model,
// shader: Shader,
// camera: Camera,
// texture: Texture,

pub fn initialize(window: ?win32.foundation.HWND) @This() {
    var direct = Direct3D{};

    direct.initialize(WIDTH, HEIGHT, window);
    return .{
        .direct3D = direct,
        // .model = Model.initialize(direct.device),
        // .shader = Shader.initialize(direct.device),
        // .camera = Camera.init(direct.device, WIDTH, HEIGHT),
        // .texture = Texture.init(direct.device, "assets/player32.bmp"),
    };
}

pub fn frame(self: *@This()) bool {
    return self.render();
}

pub fn render(self: *@This()) bool {
    self.direct3D.beginScene(0, 0, 0, 1);

    // // self.shader.render(self.direct3D.deviceContext);
    // // self.model.render(self.direct3D.deviceContext);
    // // self.texture.draw(self.direct3D.deviceContext);
    // // self.camera.render(self.direct3D.deviceContext, self.texture.model);
    self.direct3D.render();

    self.direct3D.endScene();
    return true;
}

pub fn shutdown(self: *@This()) void {
    // self.shader.shutdown();
    // self.model.shutdown();
    // self.texture.deinit();
    // self.camera.deinit();
    self.direct3D.shutdown();
}
