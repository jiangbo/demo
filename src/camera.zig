const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/2d.glsl.zig");
const window = @import("window.zig");

const Camera = @This();

pub var rect: math.Rectangle = undefined;
var border: math.Vector = undefined;
var viewMatrix: [16]f32 = undefined;
var renderPass: gpu.RenderPassEncoder = undefined;
var bindGroup: gpu.BindGroup = .{};
var pipeline: gpu.RenderPipeline = undefined;

var vertexBuffer: []gpu.Vertex = undefined;
var buffer: gpu.Buffer = undefined;

var batchDrawCount: u32 = 0;
var batchTexture: gpu.Texture = undefined;

pub fn init(r: math.Rectangle, b: math.Vector, vertex: []gpu.Vertex, index: []u16) void {
    rect = r;
    border = b;

    viewMatrix = .{
        2 / rect.size().x, 0,                  0, 0,
        0,                 2 / -rect.size().y, 0, 0,
        0,                 0,                  1, 0,
        -1,                1,                  0, 1,
    };

    bindGroup.bindIndexBuffer(gpu.createBuffer(.{
        .type = .INDEXBUFFER,
        .data = gpu.asRange(index),
    }));

    buffer = gpu.createBuffer(.{
        .type = .VERTEXBUFFER,
        .size = @sizeOf(gpu.Vertex) * vertex.len,
        .usage = .STREAM,
    });

    vertexBuffer = vertex;

    bindGroup.bindSampler(shader.SMP_smp, gpu.createSampler(.{}));
    pipeline = initPipeline();
}

fn initPipeline() gpu.RenderPipeline {
    var vertexLayout = gpu.VertexLayout{};
    vertexLayout.attrs[shader.ATTR_single_position0].format = .FLOAT3;
    vertexLayout.attrs[shader.ATTR_single_color0].format = .FLOAT4;
    vertexLayout.attrs[shader.ATTR_single_texcoord0].format = .FLOAT2;

    const shaderDesc = shader.singleShaderDesc(gpu.queryBackend());
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

pub fn lookAt(pos: math.Vector) void {
    const half = rect.size().scale(0.5);

    const max = border.sub(rect.size());
    const offset = pos.sub(half).clamp(.zero, max);

    rect = .init(offset, rect.size());
}

pub fn beginDraw(color: gpu.Color) void {
    renderPass = gpu.commandEncoder.beginRenderPass(color);
    batchDrawCount = 0;
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

    drawOptions(.{ .texture = tex, .sourceRect = src, .targetRect = target });
}

pub const DrawOptions = gpu.DrawOptions;
pub fn drawOptions(options: DrawOptions) void {
    viewMatrix[12] = -1 - rect.min.x * viewMatrix[0];
    viewMatrix[13] = 1 - rect.min.y * viewMatrix[5];

    const size = gpu.queryTextureSize(options.texture.image);
    renderPass.setPipeline(pipeline);

    renderPass.setUniform(shader.UB_vs_params, .{
        .viewMatrix = viewMatrix,
        .textureVec = [4]f32{ size.x, size.y, 1, 1 },
    });
    bindGroup.bindTexture(shader.IMG_tex, options.texture);

    gpu.draw(&renderPass, &bindGroup, options);
}

pub fn batchDraw(texture: gpu.Texture, position: math.Vector) void {
    const size = gpu.queryTextureSize(texture.image);
    if (size.approx(.zero)) return;

    const sourceRect = texture.area;
    const min = sourceRect.min;
    const max = sourceRect.max;

    vertexBuffer[batchDrawCount * 4 + 0] = .{
        .position = position.addY(texture.size().y),
        .uv = .init(min.x, max.y),
    };

    vertexBuffer[batchDrawCount * 4 + 1] = .{
        .position = position.add(texture.size()),
        .uv = .init(max.x, max.y),
    };

    vertexBuffer[batchDrawCount * 4 + 2] = .{
        .position = position.addX(texture.size().x),
        .uv = .init(max.x, min.y),
    };

    vertexBuffer[batchDrawCount * 4 + 3] = .{
        .position = position,
        .uv = .init(min.x, min.y),
    };

    batchTexture = texture;
    batchDrawCount += 1;
}

pub fn drawText(text: []const u8, position: math.Vector) void {
    var iterator = std.unicode.Utf8View.initUnchecked(text).iterator();

    var pos = position;
    while (iterator.nextCodepoint()) |code| {
        const char = window.fonts.get(code).?;
        const size = math.Vector.init(char.width, char.height);
        const area = math.Rectangle.init(.init(char.x, char.y), size);
        const tex = window.fontTexture.subTexture(area);
        batchDraw(tex, pos);
        pos = pos.addX(char.xAdvance);
    }
}

const sk = @import("sokol");
pub fn endDraw() void {
    if (batchDrawCount != 0) {
        for (vertexBuffer) |*value| {
            value.position.z = 0;
        }

        sk.gfx.updateBuffer(buffer, sk.gfx.asRange(vertexBuffer));

        bindGroup.bindVertexBuffer(buffer);
        renderPass.setPipeline(pipeline);
        bindGroup.bindTexture(shader.IMG_tex, batchTexture);
        const size = gpu.queryTextureSize(batchTexture.image);
        renderPass.setUniform(shader.UB_vs_params, .{
            .viewMatrix = viewMatrix,
            .textureVec = [4]f32{ size.x, size.y, 1, 1 },
        });
        renderPass.setBindGroup(bindGroup);
        sk.gfx.draw(0, 6 * batchDrawCount, 1);
    }

    renderPass.end();
    gpu.commandEncoder.submit();
}
