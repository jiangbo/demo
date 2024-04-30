const std = @import("std");
const zstbi = @import("zstbi");
const Texture2D = @import("texture.zig").Texture2D;
const Shader = @import("shader.zig").Shader;

pub const Texture2DEnum = enum { face, block, solid_block, background };
// pub const Texture2DUnion = union([]const u8) {
//     face: "assets/awesomeface.png",
// };
pub const ShaderEnum = enum { shader };

var textures: std.EnumMap(Texture2DEnum, Texture2D) = undefined;
var shaders: std.EnumMap(ShaderEnum, Shader) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    zstbi.init(allocator);

    textures = std.EnumMap(Texture2DEnum, Texture2D){};
    shaders = std.EnumMap(ShaderEnum, Shader){};
}

const cstr = [:0]const u8;
pub fn loadShader(name: ShaderEnum, vs: cstr, fs: cstr) Shader {
    const shader = Shader.init(vs, fs);
    shaders.put(name, shader);
    return shader;
}

pub fn getShader(name: ShaderEnum) Shader {
    return shaders.get(name).?;
}

pub fn loadTexture(name: Texture2DEnum, file: cstr) !Texture2D {
    var image = try zstbi.Image.loadFromFile(file, 4);
    defer image.deinit();

    var texture = Texture2D{};
    texture.generate(image.width, image.height, image.data);

    textures.put(name, texture);
    return texture;
}

pub fn getTexture(name: Texture2DEnum) Texture2D {
    return textures.get(name).?;
}

pub fn deinit() void {
    var textureIterator = textures.iterator();
    while (textureIterator.next()) |texture| texture.value.deinit();
    var shaderIterator = shaders.iterator();
    while (shaderIterator.next()) |shader| shader.value.deinit();
    zstbi.deinit();
}
