const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/texture.glsl.zig");
const window = @import("window.zig");
const font = @import("font.zig");

pub const Vertex = extern struct {
    position: math.Vector3, // 顶点坐标
    color: gpu.Color, // 顶点颜色
    uv: math.Vector2 = .zero, // 纹理坐标
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
var texture: gpu.Texture = .{ .image = .{} };
var debugTexture: gpu.Texture = undefined;

pub fn init(r: math.Rectangle, vertex: []Vertex) void {
    rect = r;

    const x, const y = .{ rect.size().x, rect.size().y };
    viewMatrix = .{
        2 / x, 0, 0, 0, 0,  2 / -y, 0, 0,
        0,     0, 1, 0, -1, 1,      0, 1,
    };

    bindGroup.setIndexBuffer(gpu.createBuffer(.{
        .usage = .{ .index_buffer = true, .immutable = true },
        .data = gpu.asRange(initIndexBuffer(vertex)),
    }));

    buffer = gpu.createBuffer(.{
        .size = @sizeOf(Vertex) * vertex.len,
        .usage = .{ .vertex_buffer = true, .stream_update = true },
    });

    sampler = gpu.createSampler(.{});
    pipeline = initPipeline();

    const data: [64]u8 = [1]u8{0xFF} ** 64;
    debugTexture = gpu.createTexture(.init(4, 4), &data);
}

fn initIndexBuffer(vertex: []Vertex) []u16 {
    var indexBuffer: [*]u16 = @ptrCast(@alignCast(vertex.ptr));
    var index: u16 = 0;
    while (index < vertex.len) : (index += 1) {
        indexBuffer[index * 6 + 0] = index * 4 + 0;
        indexBuffer[index * 6 + 1] = index * 4 + 1;
        indexBuffer[index * 6 + 2] = index * 4 + 2;
        indexBuffer[index * 6 + 3] = index * 4 + 0;
        indexBuffer[index * 6 + 4] = index * 4 + 2;
        indexBuffer[index * 6 + 5] = index * 4 + 3;
    }
    return indexBuffer[0 .. vertex.len / 4 * 6];
}

fn initPipeline() gpu.RenderPipeline {
    var vertexLayout = gpu.VertexLayout{};
    vertexLayout.attrs[shader.ATTR_texture_position0].format = .FLOAT3;
    vertexLayout.attrs[shader.ATTR_texture_color0].format = .FLOAT4;
    vertexLayout.attrs[shader.ATTR_texture_texcoord0].format = .FLOAT2;

    const shaderDesc = shader.textureShaderDesc(gpu.queryBackend());
    return gpu.createRenderPipeline(.{
        .shader = gpu.createShaderModule(shaderDesc),
        .vertexLayout = vertexLayout,
        .color = .{ .blend = .{
            .enabled = true,
            .src_factor_rgb = .SRC_ALPHA,
            .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        } },
        .index_type = .UINT16,
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
    drawOptions(.{
        .texture = debugTexture,
        .source = debugTexture.area,
        .target = area,
        .color = color,
    });
}

pub fn debugDraw(area: math.Rectangle) void {
    drawRectangle(area, .{ .r = 1, .b = 1, .a = 0.4 });
}

pub fn draw(tex: gpu.Texture, position: math.Vector) void {
    drawFlipX(tex, position, false);
}

pub fn drawFlipX(tex: gpu.Texture, pos: math.Vector, flipX: bool) void {
    const target: math.Rectangle = .init(pos, tex.size());
    var src = tex.area;
    if (flipX) {
        src.min.x = tex.area.max.x;
        src.max.x = tex.area.min.x;
    }

    drawOptions(.{ .texture = tex, .source = src, .target = target });
}

const DrawOptions = struct {
    texture: gpu.Texture,
    source: math.Rectangle,
    target: math.Rectangle,
    radians: f32 = 0,
    pivot: math.Vector = .zero,
    color: gpu.Color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
};

pub fn drawOptions(options: DrawOptions) void {
    var vertexes = createVertexes(options.source, options.target);
    for (&vertexes) |*value| value.position.z = 0.5;
    for (&vertexes) |*value| value.color = options.color;

    gpu.appendBuffer(buffer, &vertexes);

    defer {
        needDrawCount += 1;
        totalDrawCount += 1;
        texture = options.texture;
    }

    if (totalDrawCount == 0) return; // 第一次绘制
    if (options.texture.image.id != texture.image.id)
        drawCurrentCache();
}

pub const drawText = font.drawText;
pub const drawTextOptions = font.drawTextOptions;

pub fn endDraw() void {
    if (needDrawCount != 0) drawCurrentCache();
    font.draw(&renderPass, &bindGroup);

    renderPass.end();
    gpu.commandEncoder.submit();
}

fn createVertexes(src: math.Rectangle, dst: math.Rectangle) [4]Vertex {
    var vertexes: [4]Vertex = undefined;

    vertexes[0].position = dst.min.addY(dst.size().y);
    vertexes[0].uv = .init(src.min.x, src.max.y);

    vertexes[1].position = dst.max;
    vertexes[1].uv = .init(src.max.x, src.max.y);

    vertexes[2].position = dst.min.addX(dst.size().x);
    vertexes[2].uv = .init(src.max.x, src.min.y);

    vertexes[3].position = dst.min;
    vertexes[3].uv = .init(src.min.x, src.min.y);
    return vertexes;
}

const VertexOptions = struct {
    texture: gpu.Texture,
    vertexBuffer: gpu.Buffer,
    indexOffset: u32 = 0,
    count: u32,
};
pub fn drawVertex(options: VertexOptions) void {

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
    bindGroup.setSampler(shader.SMP_smp, sampler);

    bindGroup.setIndexOffset(options.indexOffset * 6 * @sizeOf(u16));
    renderPass.setBindGroup(bindGroup);

    // 绘制
    renderPass.draw(options.count * 6);
}

fn drawCurrentCache() void {
    drawVertex(.{
        .texture = texture,
        .vertexBuffer = buffer,
        .indexOffset = totalDrawCount - needDrawCount,
        .count = needDrawCount,
    });
    needDrawCount = 0;
}
