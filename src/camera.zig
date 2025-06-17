const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const window = @import("window.zig");
const font = @import("font.zig");

pub const Vertex = extern struct {
    position: math.Vector3, // 顶点坐标
    rotation: f32 = 0, // 旋转角度
    size: math.Vector2, // 大小
    pivot: math.Vector2 = .zero, // 旋转中心
    texture: math.Vector4, // 纹理坐标
    color: gpu.Color = .{ .r = 1, .g = 1, .b = 1, .a = 1 }, // 顶点颜色
};

pub var rect: math.Rectangle = undefined;

var viewMatrix: [16]f32 = undefined;
var sampler: gpu.Sampler = undefined;
var renderPass: gpu.RenderPassEncoder = undefined;
var bindGroup: gpu.BindGroup = .{};
var pipeline: gpu.RenderPipeline = undefined;

var buffer: gpu.Buffer = undefined;
var needDrawCount: u32 = 0;
var totalDrawCount: u32 = 0;
var usingTexture: gpu.Texture = .{ .image = .{} };
var whiteTexture: gpu.Texture = undefined;

pub fn init(r: math.Rectangle, vertex: []Vertex) void {
    rect = r;

    const x, const y = .{ rect.size().x, rect.size().y };
    viewMatrix = .{
        2 / x, 0, 0, 0, 0,  2 / -y, 0, 0,
        0,     0, 1, 0, -1, 1,      0, 1,
    };

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
    return position.add(rect.min);
}

pub fn toWindowPosition(position: math.Vector) math.Vector {
    return position.sub(rect.min);
}

pub fn beginDraw(color: gpu.Color) void {
    renderPass = gpu.commandEncoder.beginRenderPass(color);
    totalDrawCount = 0;
}

pub fn drawRectangle(area: math.Rectangle, color: gpu.Color) void {
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

pub fn draw(tex: gpu.Texture, position: math.Vector) void {
    drawFlipX(tex, position, false);
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
    gpu.appendBuffer(buffer, &[1]Vertex{vertex});

    defer {
        needDrawCount += 1;
        totalDrawCount += 1;
        usingTexture = texture;
    }

    if (totalDrawCount == 0) return; // 第一次绘制
    if (texture.image.id != usingTexture.image.id) drawCurrentCache();
}

pub const drawText = font.drawText;
pub const drawTextOptions = font.drawTextOptions;

pub fn endDraw() void {
    if (needDrawCount != 0) drawCurrentCache();
    font.draw(&renderPass, &bindGroup);

    renderPass.end();
    gpu.commandEncoder.submit();
}

const VertexOptions = struct {
    texture: gpu.Texture,
    vertexBuffer: gpu.Buffer,
    offset: u32 = 0,
    count: u32,
};
pub fn drawVertexBuffer(options: VertexOptions) void {

    // 绑定流水线
    renderPass.setPipeline(pipeline);

    // 处理 uniform 变量
    viewMatrix[12] = -1 - rect.min.x * viewMatrix[0];
    viewMatrix[13] = 1 - rect.min.y * viewMatrix[5];
    const size = gpu.queryTextureSize(options.texture.image);
    renderPass.setUniform(shader.UB_vs_params, .{
        .viewMatrix = viewMatrix,
        .textureVec = [4]f32{ size.x, size.y, 1, 1 },
    });

    // 绑定组
    bindGroup.setTexture(shader.IMG_tex, options.texture);
    bindGroup.setVertexBuffer(options.vertexBuffer);
    bindGroup.setVertexOffset(options.offset * @sizeOf(Vertex));
    bindGroup.setSampler(shader.SMP_smp, sampler);

    renderPass.setBindGroup(bindGroup);

    // 绘制
    renderPass.drawInstanced(options.count);
}

fn drawCurrentCache() void {
    drawVertexBuffer(.{
        .texture = usingTexture,
        .vertexBuffer = buffer,
        .offset = totalDrawCount - needDrawCount,
        .count = needDrawCount,
    });
    needDrawCount = 0;
}
