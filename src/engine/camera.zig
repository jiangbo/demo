const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const window = @import("window.zig");
const font = @import("font.zig");

pub var worldPosition: math.Vector3 = .zero;

var bindGroup: gpu.BindGroup = .{};
var pipeline: gpu.RenderPipeline = undefined;

var buffer: gpu.Buffer = undefined;
var needDrawCount: usize = 0;
var totalDrawCount: usize = 0;
var usingTexture: gpu.Texture = .{ .image = .{} };
var whiteTexture: gpu.Texture = undefined;

pub fn init(vertexCount: usize) void {
    buffer = gpu.createBuffer(.{
        .size = @sizeOf(gpu.QuadVertex) * vertexCount,
        .usage = .{ .vertex_buffer = true, .stream_update = true },
    });

    const shaderDesc = shader.quadShaderDesc(gpu.queryBackend());
    pipeline = gpu.createQuadPipeline(shaderDesc);

    const data: [64]u8 = [1]u8{0xFF} ** 64;
    whiteTexture = gpu.createTexture(.init(4, 4), &data);
}

pub fn toWorldPosition(position: math.Vector) math.Vector {
    return position.add(worldPosition);
}

pub fn toWindowPosition(position: math.Vector) math.Vector {
    return position.sub(worldPosition);
}

pub fn beginDraw() void {
    totalDrawCount = 0;
    font.beginDraw();
}

pub fn drawRectangle(area: math.Rectangle, color: math.Vector4) void {
    drawVertex(whiteTexture, &.{gpu.QuadVertex{
        .position = area.min,
        .size = area.size().toVector2(),
        .texture = whiteTexture.area.toVector4(),
        .color = color,
    }});
}

pub fn debugDraw(area: math.Rectangle) void {
    drawRectangle(area, .{ .x = 1, .z = 1, .w = 0.4 });
}

pub fn draw(texture: gpu.Texture, position: math.Vector) void {
    drawFlipX(texture, position, false);
}

pub fn drawFlipX(texture: gpu.Texture, pos: math.Vector, flipX: bool) void {
    var textureArea = texture.area;
    if (flipX) {
        textureArea.min.x = texture.area.max.x;
        textureArea.max.x = texture.area.min.x;
    }

    drawVertex(texture, &.{gpu.QuadVertex{
        .position = pos,
        .size = texture.size().toVector2(),
        .texture = textureArea.toVector4(),
    }});
}

pub fn drawVertex(texture: gpu.Texture, vertex: []const gpu.QuadVertex) void {
    gpu.appendBuffer(buffer, vertex);

    defer {
        needDrawCount += vertex.len;
        totalDrawCount += vertex.len;
        usingTexture = texture;
    }

    if (totalDrawCount == 0) return; // 第一次绘制
    if (texture.image.id != usingTexture.image.id) drawCurrentCache();
}

pub fn flush() void {
    if (needDrawCount != 0) drawCurrentCache();
    font.flush();
}

pub fn endDraw() void {
    flush();
}

pub const Vertex = gpu.QuadVertex;
const VertexOptions = struct {
    vertexBuffer: gpu.Buffer,
    vertexOffset: usize = 0,
    count: usize,
};
pub fn drawVertexBuffer(texture: gpu.Texture, options: VertexOptions) void {

    // 绑定流水线
    gpu.setPipeline(pipeline);

    // 处理 uniform 变量
    const x, const y = .{ window.size.x, window.size.y };
    var viewMatrix: [16]f32 = .{
        2 / x, 0, 0, 0, 0,  2 / -y, 0, 0,
        0,     0, 1, 0, -1, 1,      0, 1,
    };
    viewMatrix[12] = -1 - worldPosition.x * viewMatrix[0];
    viewMatrix[13] = 1 - worldPosition.y * viewMatrix[5];
    const size = gpu.queryTextureSize(texture.image);
    gpu.setUniform(shader.UB_vs_params, .{
        .viewMatrix = viewMatrix,
        .textureVec = [4]f32{ size.x, size.y, 1, 1 },
    });

    // 绑定组
    bindGroup.setTexture(texture);
    bindGroup.setVertexBuffer(options.vertexBuffer);
    bindGroup.setVertexOffset(options.vertexOffset * @sizeOf(Vertex));
    bindGroup.setSampler(gpu.nearestSampler);

    gpu.setBindGroup(bindGroup);

    // 绘制
    gpu.drawInstanced(options.count);
}

fn drawCurrentCache() void {
    drawVertexBuffer(usingTexture, .{
        .vertexBuffer = buffer,
        .vertexOffset = totalDrawCount - needDrawCount,
        .count = needDrawCount,
    });
    needDrawCount = 0;
}

pub const drawText = font.drawText;
pub const drawColorText = font.drawColorText;
pub const drawTextOptions = font.drawTextOptions;
pub const flushText = font.flush;

pub fn imageDrawCount() usize {
    return totalDrawCount;
}

pub fn textDrawCount() usize {
    return font.totalDrawCount;
}

pub fn gpuDrawCount() usize {
    return gpu.drawCount;
}
