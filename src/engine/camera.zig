const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const window = @import("window.zig");
const font = @import("font.zig");

const Texture = gpu.Texture;
const Vector = math.Vector;
pub const Vertex = gpu.QuadVertex;

pub var mode: enum { world, local } = .world;
pub var position: math.Vector = .zero;

var bindGroup: gpu.BindGroup = .{};
var pipeline: gpu.RenderPipeline = undefined;

var buffer: gpu.Buffer = undefined;
var needDrawCount: usize = 0;
var totalDrawCount: usize = 0;
var usingTexture: gpu.Texture = .{ .image = .{} };
var whiteTexture: gpu.Texture = undefined;

pub fn init(vertexCount: usize) void {
    buffer = gpu.createBuffer(.{
        .size = @sizeOf(Vertex) * vertexCount,
        .usage = .{ .stream_update = true },
    });

    const shaderDesc = shader.quadShaderDesc(gpu.queryBackend());
    pipeline = gpu.createQuadPipeline(shaderDesc);

    const data: [64]u8 = [1]u8{0xFF} ** 64;
    whiteTexture = gpu.createTexture(.init(4, 4), &data);
}

pub fn toWorld(windowPosition: Vector) Vector {
    return windowPosition.add(position);
}

pub fn toWindow(worldPosition: Vector) Vector {
    return worldPosition.sub(position);
}

pub fn beginDraw() void {
    totalDrawCount = 0;
    font.beginDraw();
}

pub fn debugDraw(area: math.Rectangle) void {
    drawRectangle(area, .{ .x = 1, .z = 1, .w = 0.4 });
}

pub fn draw(texture: gpu.Texture, pos: math.Vector) void {
    drawOption(texture, pos, .{});
}

pub fn drawFlipX(texture: Texture, pos: Vector, flipX: bool) void {
    drawOption(texture, pos, .{ .flipX = flipX });
}

pub fn drawRectangle(area: math.Rectangle, color: math.Vector4) void {
    drawOption(whiteTexture, area.min, .{
        .size = area.size(),
        .color = color,
    });
}

pub const Option = struct {
    rotation: f32 = 0, // 旋转角度
    size: ?math.Vector2 = null, // 大小
    pivot: math.Vector2 = .zero, // 旋转中心
    color: math.Vector4 = .one, // 颜色
    flipX: bool = false, // 是否水平翻转
};
pub fn drawOption(texture: Texture, pos: Vector, option: Option) void {
    var textureArea = texture.area;
    if (option.flipX) {
        textureArea.min.x = texture.area.max.x;
        textureArea.max.x = texture.area.min.x;
    }

    drawVertices(texture, &.{Vertex{
        .position = pos.toVector3(0),
        .rotation = option.rotation,
        .size = option.size orelse texture.size(),
        .pivot = option.pivot,
        .texture = textureArea.toVector4(),
        .color = option.color,
    }});
}

pub fn drawVertices(texture: Texture, vertex: []const Vertex) void {
    gpu.appendBuffer(buffer, vertex);

    defer {
        needDrawCount += vertex.len;
        totalDrawCount += vertex.len;
        usingTexture = texture;
    }

    if (totalDrawCount == 0) return; // 第一次绘制
    if (texture.image.id != usingTexture.image.id) flushTexture();
}

pub fn flushTexture() void {
    if (needDrawCount == 0) return;
    drawInstanced(usingTexture, .{
        .vertexBuffer = buffer,
        .vertexOffset = totalDrawCount - needDrawCount,
        .count = needDrawCount,
    });
    needDrawCount = 0;
}

pub fn flushTextureAndText() void {
    flushTexture();
    font.flush();
}

pub fn endDraw() void {
    flushTextureAndText();
}

pub fn scissor(area: math.Rectangle) void {
    flushTextureAndText();
    const ratio = window.displayArea.size().div(window.size);
    gpu.scissor(math.Rectangle{
        .min = area.min.scale(ratio.x).add(window.displayArea.min),
        .max = area.max.scale(ratio.x).add(window.displayArea.min),
    });
}
pub fn resetScissor() void {
    flushTextureAndText();
    gpu.scissor(.{ .min = .zero, .max = window.screenSize() });
}

const VertexOptions = struct {
    vertexBuffer: gpu.Buffer,
    vertexOffset: usize = 0,
    count: usize,
};
fn drawInstanced(texture: gpu.Texture, options: VertexOptions) void {

    // 绑定流水线
    gpu.setPipeline(pipeline);

    // 处理 uniform 变量
    const x, const y = .{ window.size.x, window.size.y };
    var viewMatrix: [16]f32 = .{
        2 / x, 0, 0, 0, 0,  2 / -y, 0, 0,
        0,     0, 1, 0, -1, 1,      0, 1,
    };
    if (mode == .world) {
        viewMatrix[12] = -1 - position.x * viewMatrix[0];
        viewMatrix[13] = 1 - position.y * viewMatrix[5];
    }
    const size = gpu.queryTextureSize(texture.image);
    gpu.setUniform(shader.UB_vs_params, .{
        .viewMatrix = viewMatrix,
        .textureVec = [4]f32{ 1 / size.x, 1 / size.y, 1, 1 },
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

pub const frameStats = gpu.frameStats;
pub const queryFrameStats = gpu.queryFrameStats;
pub const drawNumber = font.drawNumber;
pub const drawColorNumber = font.drawColorNumber;
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
