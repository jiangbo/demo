const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const window = @import("window.zig");
const font = @import("font.zig");

pub const Vertex = font.Vertex;

pub var worldPosition: math.Vector3 = .zero;

var sampler: gpu.Sampler = undefined;
var renderPass: gpu.RenderPassEncoder = undefined;
var bindGroup: gpu.BindGroup = .{};
var pipeline: gpu.RenderPipeline = undefined;

var buffer: gpu.Buffer = undefined;
var needDrawCount: u32 = 0;
var totalDrawCount: u32 = 0;
var usingTexture: gpu.Texture = .{ .image = .{} };
var whiteTexture: gpu.Texture = undefined;

pub fn init(vertex: []Vertex) void {
    buffer = gpu.createBuffer(.{
        .size = @sizeOf(Vertex) * vertex.len,
        .usage = .{ .vertex_buffer = true, .stream_update = true },
    });

    sampler = gpu.createSampler(.{});
    pipeline = initPipeline();

    const data: [64]u8 = [1]u8{0xFF} ** 64;
    whiteTexture = gpu.createTexture(.init(4, 4), &data);
}

fn initPipeline() gpu.RenderPipeline {
    var vertexLayout = gpu.VertexLayout{};
    vertexLayout.attrs[shader.ATTR_quad_vertex_position].format = .FLOAT3;
    vertexLayout.attrs[shader.ATTR_quad_vertex_rotation].format = .FLOAT;
    vertexLayout.attrs[shader.ATTR_quad_vertex_size].format = .FLOAT2;
    vertexLayout.attrs[shader.ATTR_quad_vertex_pivot].format = .FLOAT2;
    vertexLayout.attrs[shader.ATTR_quad_vertex_texture].format = .FLOAT4;
    vertexLayout.attrs[shader.ATTR_quad_vertex_color].format = .FLOAT4;
    vertexLayout.buffers[0].step_func = .PER_INSTANCE;

    const shaderDesc = shader.quadShaderDesc(gpu.queryBackend());
    return gpu.createRenderPipeline(.{
        .shader = gpu.createShaderModule(shaderDesc),
        .vertexLayout = vertexLayout,
        .color = .{ .blend = .{
            .enabled = true,
            .src_factor_rgb = .SRC_ALPHA,
            .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        } },
        .depth = .{ .compare = .LESS_EQUAL, .write_enabled = true },
    });
}

pub fn toWorldPosition(position: math.Vector) math.Vector {
    return position.add(worldPosition);
}

pub fn toWindowPosition(position: math.Vector) math.Vector {
    return position.sub(worldPosition);
}

pub fn beginDraw(color: gpu.Color) void {
    renderPass = gpu.commandEncoder.beginRenderPass(color);
    totalDrawCount = 0;
}

pub fn drawText(text: []const u8, position: math.Vector) void {
    drawTextOptions(text, .{ .position = position });
}

pub fn drawTextOptions(text: []const u8, options: font.TextOptions) void {
    font.drawTextOptions(text, options);
}

pub fn drawRectangle(area: math.Rectangle, color: math.Vector4) void {
    drawVertex(whiteTexture, .{
        .position = area.min,
        .size = area.size().toVector2(),
        .texture = whiteTexture.area.toVector4(),
        .color = color,
    });
}

pub fn debugDraw(area: math.Rectangle) void {
    drawRectangle(area, .{ .r = 1, .b = 1, .a = 0.4 });
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

    drawVertex(texture, .{
        .position = pos,
        .size = texture.size().toVector2(),
        .texture = textureArea.toVector4(),
    });
}

pub fn drawVertex(texture: gpu.Texture, vertex: Vertex) void {
    gpu.appendBuffer(buffer, &.{vertex});

    defer {
        needDrawCount += 1;
        totalDrawCount += 1;
        usingTexture = texture;
    }

    if (totalDrawCount == 0) return; // 第一次绘制
    if (texture.image.id != usingTexture.image.id) drawCurrentCache();
}

pub fn flush() void {
    if (needDrawCount != 0) drawCurrentCache();
    font.draw(&renderPass, &bindGroup);
}

pub fn endDraw() void {
    flush();
    renderPass.end();
    gpu.commandEncoder.submit();
}

const VertexOptions = struct {
    vertexBuffer: gpu.Buffer,
    vertexOffset: u32 = 0,
    count: u32,
};
pub fn drawVertexBuffer(texture: gpu.Texture, options: VertexOptions) void {

    // 绑定流水线
    renderPass.setPipeline(pipeline);

    // 处理 uniform 变量
    const x, const y = .{ window.size.x, window.size.y };
    var viewMatrix: [16]f32 = .{
        2 / x, 0, 0, 0, 0,  2 / -y, 0, 0,
        0,     0, 1, 0, -1, 1,      0, 1,
    };
    viewMatrix[12] = -1 - worldPosition.x * viewMatrix[0];
    viewMatrix[13] = 1 - worldPosition.y * viewMatrix[5];
    const size = gpu.queryTextureSize(texture.image);
    renderPass.setUniform(shader.UB_vs_params, .{
        .viewMatrix = viewMatrix,
        .textureVec = [4]f32{ size.x, size.y, 1, 1 },
    });

    // 绑定组
    bindGroup.setTexture(shader.IMG_tex, texture);
    bindGroup.setVertexBuffer(options.vertexBuffer);
    bindGroup.setVertexOffset(options.vertexOffset * @sizeOf(Vertex));
    bindGroup.setSampler(shader.SMP_smp, sampler);

    renderPass.setBindGroup(bindGroup);

    // 绘制
    renderPass.drawInstanced(options.count);
}

fn drawCurrentCache() void {
    drawVertexBuffer(usingTexture, .{
        .vertexBuffer = buffer,
        .vertexOffset = totalDrawCount - needDrawCount,
        .count = needDrawCount,
    });
    needDrawCount = 0;
}
