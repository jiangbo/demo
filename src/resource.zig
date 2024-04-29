const std = @import("std");
const zstbi = @import("zstbi");
const gl = @import("gl");
const Texture2D = @import("texture.zig").Texture2D;
const Shader = @import("shader.zig").Shader;

var textures: std.StringHashMap(Texture2D) = undefined;
var shaders: std.StringHashMap(Shader) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    textures = std.StringHashMap(Texture2D).init(allocator);
    shaders = std.StringHashMap(Shader).init(allocator);
}

const cstr = [:0]const u8;
pub fn loadShader(name: []const u8, vs: cstr, fs: cstr) !Shader {
    const shader = Shader.init(vs, fs);
    try shaders.put(name, shader);
    return shader;
}

pub fn getShader(name: []const u8) Shader {
    return shaders.get(name).?;
}

pub fn loadTexture(name: []const u8, file: cstr) !Texture2D {
    var image = try zstbi.Image.loadFromFile(file, 4);
    defer image.deinit();

    var texture = Texture2D{};
    texture.generate(image.width, image.height, image.data);

    try textures.put(name, texture);
    return texture;
}

pub fn getTexture(name: []const u8) Texture2D {
    return textures.get(name).?;
}

pub fn deinit() void {
    var textureIterator = textures.valueIterator();
    while (textureIterator.next()) |texture| texture.deinit();
    var shaderIterator = shaders.valueIterator();
    while (shaderIterator.next()) |shader| shader.deinit();
    textures.deinit();
    shaders.deinit();
}
