const std = @import("std");

const sk = @import("sokol");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const graphics = @import("graphics.zig");
const camera = @import("camera.zig");
const window = @import("window.zig");

const Image = graphics.Image;
const ImageId = graphics.ImageId;
const Color = graphics.Color;
const Vector2 = math.Vector2;
const Matrix = math.Matrix;

pub const Command = struct {
    start: u32 = 0, // 起始顶点索引
    end: u32 = 0, // 结束顶点索引
    texture: graphics.Texture = .{}, // 纹理
    position: Vector2 = .zero, // 位置
    scale: Vector2 = .one, // 缩放
    size: Vector2 = .zero, // 大小
    type: enum { draw, scissor } = .draw, // 类型
};

pub const Vertex = extern struct {
    position: math.Vector2 = .zero, // 顶点坐标
    padding: u32 = 0, // 填充字节，保持对齐
    radian: f32 = 0, // 旋转弧度
    size: math.Vector2, // 大小
    pivot: math.Vector2 = .zero, // 旋转中心
    uvRect: math.Vector4, // 纹理 UV 区域
    color: graphics.Color = .white, // 顶点颜色
};

pub const Option = struct {
    size: ?Vector2 = null, // 大小
    scale: Vector2 = .one, // 缩放
    anchor: Vector2 = .zero, // 锚点
    pivot: Vector2 = .center, // 旋转中心
    radian: f32 = 0, // 旋转弧度
    uvRect: ?math.Vector4 = null, // 纹理 UV 区域
    color: graphics.Color = .white, // 颜色
    layer: Layer = .default, // 绘制层级
};

const Layer = enum { default, extend, text, debug };
const LayerBuffer = struct {
    pipeline: sk.gfx.Pipeline = undefined,
    sampler: sk.gfx.Sampler = undefined,
    vertices: std.ArrayList(Vertex) = .empty,
    commands: std.ArrayList(Command) = .empty,
    vertexHandle: sk.gfx.Buffer = .{},

    fn currentCommand(self: *LayerBuffer) ?*Command {
        if (self.commands.items.len == 0) return null;
        return &self.commands.items[self.commands.items.len - 1];
    }

    fn addDrawCommand(self: *LayerBuffer, texture: graphics.Texture) *Command {
        const index: u32 = if (self.currentCommand()) |cmd| blk: {
            cmd.end = @intCast(self.vertices.items.len);
            break :blk cmd.end;
        } else 0;

        self.commands.appendAssumeCapacity(.{
            .start = index,
            .texture = texture,
            .position = camera.position,
            .scale = camera.scale,
            .size = camera.size,
        });
        return &self.commands.items[self.commands.items.len - 1];
    }
};

const Stats = struct { sprites: usize = 0, commands: usize = 0 };

pub var whiteImage: graphics.Image = undefined;
pub var circleImage: graphics.Image = undefined;
pub var layers: std.EnumArray(Layer, LayerBuffer) = .initFill(.{});
pub var lastStats: Stats = .{};

var renderTarget: ?graphics.RenderTarget = null;

pub fn init(vertexes: []Vertex, commands: []Command) void {
    const shaderDesc = shader.quadShaderDesc(sk.gfx.queryBackend());
    const pipeline = createQuadPipeline(shaderDesc);
    const nearestSampler = sk.gfx.makeSampler(.{});
    for (&layers.values) |*layer| {
        layer.pipeline = pipeline;
        layer.sampler = nearestSampler;
    }

    const defaultLayer = layers.getPtr(.default);
    defaultLayer.vertices = .initBuffer(vertexes);
    defaultLayer.commands = .initBuffer(commands);
    defaultLayer.vertexHandle = sk.gfx.makeBuffer(.{
        .size = @sizeOf(Vertex) * vertexes.len,
        .usage = .{ .stream_update = true },
    });

    if (!window.viewRect.size.approxEqual(window.size)) {
        renderTarget = graphics.createRenderTarget(window.size);
    }
    camera.init();
}

pub fn beginPass(pass: graphics.RenderPass) void {
    var renderPass = pass;
    if (renderTarget) |target| renderPass.target = target;
    graphics.beginPass(renderPass);

    var iterator = layers.iterator();
    while (iterator.next()) |entry| {
        entry.value.vertices.clearRetainingCapacity();
        entry.value.commands.clearRetainingCapacity();
    }
}

pub fn flush() void {
    lastStats = .{};
}

fn drawCommands(value: Layer, commands: []const Command) void {
    for (commands) |cmd| {
        switch (cmd.type) {
            .draw => {
                if (cmd.texture.id != 0 and cmd.end > cmd.start) {
                    doDraw(value, cmd);
                }
            },
            .scissor => {
                const x, const y = .{ cmd.position.x, cmd.position.y };
                const w, const h = .{ cmd.size.x, cmd.size.y };
                sk.gfx.applyScissorRectf(x, y, w, h, true);
            },
        }
    }
}

pub fn currentCommand() ?*Command {
    return layers.getPtr(.default).currentCommand();
}

pub fn addDrawCommand(texture: graphics.Texture) *Command {
    return layers.getPtr(.default).addDrawCommand(texture);
}

pub fn appendVertexes(vertexes: []const Vertex) void {
    const layer = layers.getPtr(.default);
    layer.vertices.appendSliceAssumeCapacity(vertexes);
}

pub fn debugDraw(rect: math.Rect) void {
    drawRect(rect, .{ .color = .rgba(1, 0, 1, 0.4) });
}

pub const LineOption = struct { color: Color = .white, width: f32 = 1 };

/// 绘制轴对齐的线
pub fn drawAxisLine(start: Vector2, end: Vector2, option: LineOption) void {
    const rectOption = RectOption{ .color = option.color };
    const halfWidth = -@floor(option.width / 2);
    if (start.x == end.x) {
        const size = Vector2.xy(option.width, end.y - start.y);
        drawRect(.init(start.addX(halfWidth), size), rectOption);
    } else if (start.y == end.y) {
        const size = Vector2.xy(end.x - start.x, option.width);
        drawRect(.init(start.addY(halfWidth), size), rectOption);
    }
}

/// 绘制任意线
pub fn drawLine(start: Vector2, end: Vector2, option: LineOption) void {
    const vector = end.sub(start);
    const y = start.y - option.width / 2;
    drawImage(whiteImage, .xy(start.x, y), .{
        .size = .xy(vector.length(), option.width),
        .color = option.color,
        .radian = vector.atan2(),
        .pivot = .xy(0, 0.5),
    });
}

pub fn drawRectBorder(rect: math.Rect, width: f32, c: Color) void {
    const color = RectOption{ .color = c };
    drawRect(.init(rect.min, .xy(rect.size.x, width)), color); // 上
    var start = rect.min.addY(rect.size.y - width);
    drawRect(.init(start, .xy(rect.size.x, width)), color); // 下
    const size: Vector2 = .xy(width, rect.size.y - 2 * width);
    drawRect(.init(rect.min.addY(width), size), color); // 左
    start = rect.min.addXY(rect.size.x - width, width);
    drawRect(.init(start, size), color); // 右
}

pub const RectOption = struct { color: Color = .white, radian: f32 = 0 };
pub fn drawRect(rect: math.Rect, option: RectOption) void {
    const white = whiteImage.sub(.init(.xy(0, 4), .xy(4, 4)));
    drawImage(white, rect.min, .{
        .size = rect.size,
        .color = option.color,
        .radian = option.radian,
    });
}

pub const TriangleOption = struct {
    color: Color = .white,
    flip: bool = false,
};
pub fn drawTriangle(rect: math.Rect, option: TriangleOption) void {
    drawImage(whiteImage, rect.min, .{
        .size = rect.size,
        .color = option.color,
        .mask = .{ .flipX = option.flip },
    });
}

pub fn drawCircle(position: Vector2, option: Option) void {
    drawImage(circleImage, position, option);
}

pub const NineOption = struct { topLeft: Vector2, bottomRight: Vector2 };
pub fn drawNine(image: Image, rect: math.Rect, option: NineOption) void {
    const left = option.topLeft.x;
    const top = option.topLeft.y;
    const right = option.bottomRight.x;
    const bottom = option.bottomRight.y;

    const finalSize = rect.size.max(.xy(left + right, top + bottom));
    const centerW = finalSize.x - left - right;
    const centerH = finalSize.y - top - bottom;

    const srcX = [_]f32{ 0, left, image.size.x - right };
    const srcY = [_]f32{ 0, top, image.size.y - bottom };
    const srcW = [_]f32{ left, image.size.x - left - right, right };
    const srcH = [_]f32{ top, image.size.y - top - bottom, bottom };

    const min = rect.min;
    const dstX = [_]f32{ min.x, min.x + left, min.x + left + centerW };
    const dstY = [_]f32{ min.y, min.y + top, min.y + top + centerH };
    const dstW = [_]f32{ left, centerW, right };
    const dstH = [_]f32{ top, centerH, bottom };

    for (0..3) |row| {
        for (0..3) |col| {
            const srcPos = Vector2.xy(srcX[col], srcY[row]);
            const srcSize = Vector2.xy(srcW[col], srcH[row]);
            const pos = Vector2.xy(dstX[col], dstY[row]);
            drawImage(image.sub(.init(srcPos, srcSize)), pos, .{
                .size = .xy(dstW[col], dstH[row]),
            });
        }
    }
}

pub fn drawImage(image: Image, pos: Vector2, option: Option) void {
    const layer = layers.getPtr(option.layer);
    var cmd = layer.currentCommand() orelse layer.addDrawCommand(image.texture);
    if (cmd.texture.id != image.texture.id) {
        cmd = layer.addDrawCommand(image.texture); // 纹理切换
    }

    const size = option.size orelse image.size;
    var scaledSize = size.mul(option.scale);
    const worldPos = switch (camera.mode) {
        .world => pos,
        .window => blk: {
            scaledSize = scaledSize.div(cmd.scale);
            break :blk cmd.position.add(pos.div(cmd.scale));
        },
    };

    layer.vertices.appendAssumeCapacity(Vertex{
        .position = worldPos.sub(scaledSize.mul(option.anchor)),
        .radian = option.radian,
        .size = scaledSize,
        .pivot = option.pivot,
        .uvRect = option.uvRect orelse image.uvRect(),
        .color = option.color,
    });
}

fn doDraw(layerType: Layer, cmd: Command) void {
    const layer = layers.getPtr(layerType);

    // 绑定流水线
    sk.gfx.applyPipeline(layer.pipeline);

    // 处理 uniform 变量
    const x, const y = .{ cmd.size.x, cmd.size.y };
    const orth = math.Matrix.orthographic(x, y, 0, 1);
    const position = cmd.position.scale(-1).toVector3(0);

    const translate = math.Matrix.translateVec(position);
    const scaleMatrix = math.Matrix.scaleVec(cmd.scale.toVector3(1));
    const view = math.Matrix.mul(scaleMatrix, translate);

    const size = graphics.queryTextureSize(cmd.texture);
    const uniforms = shader.VsParams{
        .viewMatrix = math.Matrix.mul(orth, view).mat,
        .textureVec = [4]f32{ 1 / size.x, 1 / size.y, 1, 1 },
    };
    sk.gfx.applyUniforms(shader.UB_vs_params, sk.gfx.asRange(&uniforms));

    // 绑定组
    var bindings = sk.gfx.Bindings{};
    bindings.views[0] = cmd.texture;
    bindings.vertex_buffers[0] = layer.vertexHandle;
    bindings.vertex_buffer_offsets[0] = @intCast(cmd.start * @sizeOf(Vertex));
    bindings.samplers[0] = layer.sampler;
    sk.gfx.applyBindings(bindings);

    // 绘制
    sk.gfx.draw(0, 4, cmd.end - cmd.start);
}

fn createQuadPipeline(shaderDesc: sk.gfx.ShaderDesc) sk.gfx.Pipeline {
    var vertexLayout = sk.gfx.VertexLayoutState{};

    vertexLayout.attrs[0].format = .FLOAT3;
    vertexLayout.attrs[1].format = .FLOAT;
    vertexLayout.attrs[2].format = .FLOAT2;
    vertexLayout.attrs[3].format = .FLOAT2;
    vertexLayout.attrs[4].format = .FLOAT4;
    vertexLayout.attrs[5].format = .FLOAT4;
    vertexLayout.buffers[0].step_func = .PER_INSTANCE;

    return sk.gfx.makePipeline(.{
        .shader = sk.gfx.makeShader(shaderDesc),
        .layout = vertexLayout,
        .primitive_type = .TRIANGLE_STRIP,
        .colors = init: {
            var c: [8]sk.gfx.ColorTargetState = @splat(.{});
            c[0] = .{ .blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
                .src_factor_alpha = .ONE,
                .dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
            } };
            break :init c;
        },
    });
}

pub fn commandCount() usize {
    var count: usize = 0;
    for (layers.values) |layer| count += layer.commands.items.len;
    return count;
}

// fn updateStats() void {
//     var sprites = vertexBuffer.items.len;
//     var commands = commandBuffer.items.len;

//     sprites += layers.getPtr(.extend).vertices.items.len;
//     sprites += layers.getPtr(.text).vertices.items.len;
//     sprites += layers.getPtr(.debug).vertices.items.len;

//     commands += layers.getPtr(.extend).commands.items.len;
//     commands += layers.getPtr(.text).commands.items.len;
//     commands += layers.getPtr(.debug).commands.items.len;

//     lastStats = .{
//         .sprites = sprites,
//         .commands = commands,
//     };
// }
