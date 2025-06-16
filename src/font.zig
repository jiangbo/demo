const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/font.glsl.zig");
const window = @import("window.zig");

pub const Font = struct {
    atlas: struct {
        type: []const u8,
        distanceRange: u32,
        distanceRangeMiddle: u32,
        size: f32,
        width: u32,
        height: u32,
        yOrigin: []const u8,
    },
    metrics: struct {
        emSize: u32,
        lineHeight: f32,
        ascender: f32,
        descender: f32,
        underlineY: f32,
        underlineThickness: f32,
    },
    glyphs: []const Glyph,
    kerning: struct {},
};

const Glyph = struct {
    unicode: u32,
    advance: f32,
    planeBounds: Rect = .{},
    atlasBounds: Rect = .{},
};

const Rect = struct {
    left: f32 = 0,
    top: f32 = 0,
    right: f32 = 0,
    bottom: f32 = 0,

    fn toArea(self: Rect) math.Rectangle {
        return .{
            .min = .{ .x = self.left, .y = self.top },
            .max = .{ .x = self.right, .y = self.bottom },
        };
    }
};

pub const Vertex = extern struct {
    position: math.Vector3, // 顶点坐标
    color: gpu.Color, // 顶点颜色
    uv: math.Vector2 = .zero, // 纹理坐标
};

var font: Font = undefined;
var texture: gpu.Texture = undefined;

var viewMatrix: [16]f32 = undefined;
var pipeline: gpu.RenderPipeline = undefined;
var sampler: gpu.Sampler = undefined;
var buffer: gpu.Buffer = undefined;
var drawCount: u32 = 0;

const initOptions = struct {
    font: *const Font,
    texture: gpu.Texture,
    size: math.Vector,
    vertex: []Vertex,
};

pub fn init(options: initOptions) void {
    font = options.font.*;
    texture = options.texture;

    const x, const y = .{ options.size.x, options.size.y };
    viewMatrix = .{
        2 / x, 0, 0, 0, 0,  2 / -y, 0, 0,
        0,     0, 1, 0, -1, 1,      0, 1,
    };

    buffer = gpu.createBuffer(.{
        .size = @sizeOf(Vertex) * options.vertex.len,
        .usage = .{ .vertex_buffer = true, .stream_update = true },
    });

    sampler = gpu.createSampler(.{
        .min_filter = .LINEAR,
        .mag_filter = .LINEAR,
    });

    initPipeline();
}

fn initPipeline() void {
    var vertexLayout = gpu.VertexLayout{};
    vertexLayout.attrs[shader.ATTR_font_position0].format = .FLOAT3;
    vertexLayout.attrs[shader.ATTR_font_color0].format = .FLOAT4;
    vertexLayout.attrs[shader.ATTR_font_texcoord0].format = .FLOAT2;

    const shaderDesc = shader.fontShaderDesc(gpu.queryBackend());
    pipeline = gpu.createRenderPipeline(.{
        .shader = gpu.createShaderModule(shaderDesc),
        .vertexLayout = vertexLayout,
        .color = .{ .blend = .{
            .enabled = true,
            .src_factor_rgb = .SRC_ALPHA,
            .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        } },
        .index_type = .UINT16,
    });
}

fn searchGlyph(code: u32) *const Glyph {
    const i = std.sort.binarySearch(Glyph, font.glyphs, code, compare);
    return &font.glyphs[i.?];
}

fn compare(a: u32, b: Glyph) std.math.Order {
    if (a < b.unicode) return .lt;
    if (a > b.unicode) return .gt;
    return .eq;
}

const DrawOptions = struct {
    texture: gpu.Texture,
    target: math.Rectangle,
    color: gpu.Color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
};

fn drawOptions(options: DrawOptions) void {
    var vertexes = createVertexes(options.texture.area, options.target);
    for (&vertexes) |*value| value.position.z = 0.5;
    for (&vertexes) |*value| value.color = options.color;

    gpu.appendBuffer(buffer, &vertexes);
    drawCount += 1;
}

pub fn drawText(text: []const u8, position: math.Vector) void {
    drawTextOptions(.{ .text = text, .position = position });
}

const TextOptions = struct {
    text: []const u8,
    size: f32 = 18,
    position: math.Vector,
    color: gpu.Color = .{ .r = 1, .g = 1, .b = 1, .a = 1 },
};

pub fn drawTextOptions(options: TextOptions) void {
    const Utf8View = std.unicode.Utf8View;
    var iterator = Utf8View.initUnchecked(options.text).iterator();

    const offsetY = -font.metrics.ascender * options.size;
    var pos = options.position.addY(offsetY);

    while (iterator.nextCodepoint()) |code| {
        if (code == '\n') {
            const height = font.metrics.lineHeight * options.size;
            pos = .init(options.position.x, pos.y + height);
            continue;
        }
        const char = searchGlyph(code);

        const target = char.planeBounds.toArea();
        const offset = pos.add(target.min.scale(options.size));
        drawOptions(.{
            .texture = texture.subTexture(char.atlasBounds.toArea()),
            .target = .init(offset, target.size().scale(options.size)),
            .color = options.color,
        });
        pos = pos.addX(char.advance * options.size);
    }
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

pub fn draw(renderPass: *gpu.RenderPassEncoder, bindGroup: *gpu.BindGroup) void {

    // 绑定流水线
    renderPass.setPipeline(pipeline);

    // 处理 uniform 变量
    const size = gpu.queryTextureSize(texture.image);
    renderPass.setUniform(shader.UB_vs_params, .{
        .viewMatrix = viewMatrix,
        .textureVec = [4]f32{ size.x, size.y, 1, 1 },
    });

    // 绑定组
    bindGroup.setSampler(shader.SMP_smp, sampler);
    bindGroup.setTexture(shader.IMG_tex, texture);
    bindGroup.setVertexBuffer(buffer);

    bindGroup.setIndexOffset(0);
    renderPass.setBindGroup(bindGroup.*);

    // 绘制
    renderPass.draw(drawCount * 6);
    drawCount = 0;
}
