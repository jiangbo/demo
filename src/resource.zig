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

pub fn deinit() void {
    textures.deinit();
    shaders.deinit();
}

const cstr = [:0]const u8;
pub fn loadShader(name: []const u8, vs: cstr, fs: cstr) !engine.Shader {
    const shader = engine.Shader.init(vs, fs);
    try shaders.put(name, shader);
    return shader;
}

fn getShader(name: []const u8) engine.Shader {
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

fn getTexture(name: []const u8) engine.Texture {
    return textures.get(name).?;
}

// void ResourceManager::Clear()
// {
//     // (Properly) delete all shaders
//     for (auto iter : Shaders)
//         glDeleteProgram(iter.second.ID);
//     // (Properly) delete all textures
//     for (auto iter : Textures)
//         glDeleteTextures(1, &iter.second.ID);
// }

// Shader ResourceManager::loadShaderFromFile(const GLchar *vShaderFile, const GLchar *fShaderFile, const GLchar *gShaderFile)
// {
//     // 1. Retrieve the vertex/fragment source code from filePath
//     std::string vertexCode;
//     std::string fragmentCode;
//     std::string geometryCode;
//     try
//     {
//         // Open files
//         std::ifstream vertexShaderFile(vShaderFile);
//         std::ifstream fragmentShaderFile(fShaderFile);
//         std::stringstream vShaderStream, fShaderStream;
//         // Read file's buffer contents into streams
//         vShaderStream << vertexShaderFile.rdbuf();
//         fShaderStream << fragmentShaderFile.rdbuf();
//         // close file handlers
//         vertexShaderFile.close();
//         fragmentShaderFile.close();
//         // Convert stream into string
//         vertexCode = vShaderStream.str();
//         fragmentCode = fShaderStream.str();
//         // If geometry shader path is present, also load a geometry shader
//         if (gShaderFile != nullptr)
//         {
//             std::ifstream geometryShaderFile(gShaderFile);
//             std::stringstream gShaderStream;
//             gShaderStream << geometryShaderFile.rdbuf();
//             geometryShaderFile.close();
//             geometryCode = gShaderStream.str();
//         }
//     }
//     catch (std::exception e)
//     {
//         std::cout << "ERROR::SHADER: Failed to read shader files" << std::endl;
//     }
//     const GLchar *vShaderCode = vertexCode.c_str();
//     const GLchar *fShaderCode = fragmentCode.c_str();
//     const GLchar *gShaderCode = geometryCode.c_str();
//     // 2. Now create shader object from source code
//     Shader shader;
//     shader.Compile(vShaderCode, fShaderCode, gShaderFile != nullptr ? gShaderCode : nullptr);
//     return shader;
// }

// Texture2D ResourceManager::loadTextureFromFile(const GLchar *file, GLboolean alpha)
// {
//     // Create Texture object
//     Texture2D texture;
//     if (alpha)
//     {
//         texture.Internal_Format = GL_RGBA;
//         texture.Image_Format = GL_RGBA;
//     }
//     // Load image
//     int width, height;
//     unsigned char* image = SOIL_load_image(file, &width, &height, 0, texture.Image_Format == GL_RGBA ? SOIL_LOAD_RGBA : SOIL_LOAD_RGB);
//     // Now generate texture
//     texture.Generate(width, height, image);
//     // And finally free image data
//     SOIL_free_image_data(image);
//     return texture;
// }
