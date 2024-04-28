const std = @import("std");
const engine = @import("engine.zig");
const zstbi = @import("zstbi");
const gl = @import("gl");

var textures: std.StringHashMap(engine.Texture) = undefined;
var shaders: std.StringHashMap(engine.Shader) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    textures = std.StringHashMap(engine.Texture).init(allocator);
    shaders = std.StringHashMap(engine.Shader).init(allocator);
}

const cstr = [:0]const u8;
pub fn loadShader(name: []const u8, vs: cstr, fs: cstr) !engine.Shader {
    const shader = engine.Shader.init(vs, fs);
    try shaders.put(name, shader);
    return shader;
}

pub fn getShader(name: []const u8) engine.Shader {
    return shaders.get(name).?;
}

pub fn loadTexture(name: []const u8, file: cstr, alpha: bool) !engine.Texture {
    var image = try zstbi.Image.loadFromFile(file, 0);
    defer image.deinit();

    var texture = engine.Texture.init(image.data);
    texture.width = @intCast(image.width);
    texture.height = @intCast(image.height);

    const internal: c_int = if (alpha) gl.RGBA else gl.RGB;
    const format: c_uint = if (alpha) gl.RGBA else gl.RGB;
    texture.generate(internal, format);

    try textures.put(name, texture);
    return texture;
}

pub fn getTexture(name: []const u8) engine.Texture {
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
