const std = @import("std");

const sk = @import("sokol");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const graphics = @import("graphics.zig");
const camera = @import("camera.zig");
const window = @import("window.zig");

const Image = graphics.Image;
const ImageId = graphics.ImageId;
const Texture = graphics.Texture;
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
    mode: ?@TypeOf(camera.mode) = null, // 相机模式
    layer: Layer.Name = .default, // 绘制层级
};

pub const Layer = struct {
    pub const Name = enum { default, extend, text, debug };
    pipeline: sk.gfx.Pipeline = .{},
    sampler: sk.gfx.Sampler = .{},
    vertices: std.ArrayList(Vertex) = .empty,
    commands: std.ArrayList(Command) = .empty,
    vertexHandle: sk.gfx.Buffer = .{},

    pub fn currentCommand(self: *Layer) ?*Command {
        if (self.commands.items.len == 0) return null;
        return &self.commands.items[self.commands.items.len - 1];
    }

    pub fn addDrawCommand(self: *Layer, command: Command) *Command {
        var finalCommand = command;
        finalCommand.start = if (self.currentCommand()) |cmd| blk: {
            cmd.end = @intCast(self.vertices.items.len);
            break :blk cmd.end;
        } else 0;
        self.commands.appendAssumeCapacity(finalCommand);
        return &self.commands.items[self.commands.items.len - 1];
    }

    pub fn drawCommand(self: *Layer, command: Command) *Command {
        if (self.currentCommand()) |cmd| {
            if (cmd.texture.id == command.texture.id) return cmd;
            return self.addDrawCommand(command);
        } else return self.addDrawCommand(command);
    }

    fn uploadVertices(self: *Layer) void {
        if (self.currentCommand()) |cmd| {
            cmd.end = @intCast(self.vertices.items.len);
        } else return;

        const buffer = sk.gfx.asRange(self.vertices.items);
        _ = sk.gfx.updateBuffer(self.vertexHandle, buffer);
    }
};

pub var nearestSampler: sk.gfx.Sampler = undefined;
pub var linearSampler: sk.gfx.Sampler = undefined;

pub var whiteImage: graphics.Image = undefined;
pub var circleImage: graphics.Image = undefined;
pub var layers: std.EnumArray(Layer.Name, Layer) = .initFill(.{});
pub const vertexBuffer = &layers.getPtr(.default).vertices;
pub const commandBuffer = &layers.getPtr(.default).commands;

var renderTarget: ?graphics.RenderTarget = null;

pub fn init(vertices: []Vertex, commands: []Command) void {
    const layer = layers.getPtr(.default);
    layer.vertices = .initBuffer(vertices);
    layer.commands = .initBuffer(commands);
    if (@import("builtin").is_test) return;

    nearestSampler = sk.gfx.makeSampler(.{});
    linearSampler = sk.gfx.makeSampler(.{
        .min_filter = .LINEAR,
        .mag_filter = .LINEAR,
    });

    const shaderDesc = shader.quadShaderDesc(sk.gfx.queryBackend());
    layer.pipeline = createQuadPipeline(shaderDesc);
    layer.sampler = nearestSampler;
    layer.vertexHandle = createVertexHandle(vertices);

    if (!window.viewRect.size.approxEqual(window.size)) {
        renderTarget = graphics.createRenderTarget(window.size);
    }
    camera.init();
}

pub fn clear() void {
    graphics.stats = .{};
    for (&layers.values) |*layer| {
        layer.vertices.clearRetainingCapacity();
        layer.commands.clearRetainingCapacity();
    }
}

pub fn createVertexHandle(vertices: []Vertex) sk.gfx.Buffer {
    return sk.gfx.makeBuffer(.{
        .size = @sizeOf(Vertex) * vertices.len,
        .usage = .{ .stream_update = true },
    });
}

pub fn beginPass(color: graphics.Color) void {
    clear();
    var renderPass = graphics.RenderPass{ .clear = color };
    if (renderTarget) |target| renderPass.target = target;
    graphics.beginPass(renderPass);
}

pub fn currentCommand() ?*Command {
    return layers.getPtr(.default).currentCommand();
}

pub fn addDrawCommand(texture: graphics.Texture) *Command {
    return layers.getPtr(.default).addDrawCommand(defaultCommand(texture));
}

fn defaultCommand(texture: graphics.Texture) Command {
    return .{
        .texture = texture,
        .position = camera.position,
        .scale = camera.scale,
        .size = camera.size,
    };
}

pub fn drawDebug(rect: math.Rect) void {
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

pub fn drawCircle(position: Vector2, option: Option) void {
    drawImage(circleImage, position, option);
}

pub fn drawAxisCapsule(rect: math.Rect, color: Color) void {
    if (rect.size.x <= 0 or rect.size.y <= 0) return;

    if (rect.size.x >= rect.size.y) {
        const radius = rect.size.y * 0.5;
        const half = circleImage.size.mul(.xy(0.5, 1));
        const size = Vector2.xy(radius, rect.size.y);

        var image = circleImage.sub(.init(.zero, half));
        drawImage(image, rect.min, .{ .size = size, .color = color });

        const middleRect = math.Rect.init(
            rect.min.addX(radius),
            .xy(rect.size.x - rect.size.y, rect.size.y),
        );
        if (middleRect.size.x > 0 and middleRect.size.y > 0) {
            drawRect(middleRect, .{ .color = color });
        }

        image = circleImage.sub(.init(.xy(half.x, 0), half));
        const pos = rect.min.addX(middleRect.size.x + radius);
        drawImage(image, pos, .{ .size = size, .color = color });
        return;
    }

    const radius = rect.size.x * 0.5;
    const half = circleImage.size.mul(.xy(1, 0.5));
    const size = Vector2.xy(rect.size.x, radius);

    var image = circleImage.sub(.init(.zero, half));
    drawImage(image, rect.min, .{ .size = size, .color = color });

    const middleRect = math.Rect.init(
        rect.min.addY(radius),
        .xy(rect.size.x, rect.size.y - rect.size.x),
    );
    if (middleRect.size.x > 0 and middleRect.size.y > 0) {
        drawRect(middleRect, .{ .color = color });
    }

    image = circleImage.sub(.init(.xy(0, half.y), half));
    const pos = rect.min.addY(middleRect.size.y + radius);
    drawImage(image, pos, .{ .size = size, .color = color });
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
    const cmd = layer.drawCommand(defaultCommand(image.texture));

    const size = option.size orelse image.size;
    var scaledSize = size.mul(option.scale);
    const worldPos = switch (option.mode orelse camera.mode) {
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

pub fn flush() void {
    if (renderTarget) |target| {
        const layer = layers.getPtr(.default);
        const index = layer.commands.items.len;

        const flipY = !sk.gfx.queryFeatures().origin_top_left;
        drawImage(target.image, .zero, .{
            .mode = .window,
            .uvRect = target.image.uvFlip(false, flipY),
        });

        layer.uploadVertices();
        drawCommands(layer, layer.commands.items[0..index]);
        for (layers.values[1..]) |*other| {
            other.uploadVertices();
            drawCommands(other, other.commands.items);
        }

        graphics.endPass();
        graphics.beginPass(.{ .clear = .black });
        drawCommands(layer, layer.commands.items[index..]);
    } else for (&layers.values) |*layer| {
        layer.uploadVertices();
        drawCommands(layer, layer.commands.items);
    }

    for (layers.values) |layer| {
        graphics.stats.sprite += layer.vertices.items.len;
        graphics.stats.command += layer.commands.items.len;
    }
}

pub fn endPass() void {
    graphics.endPass();
    graphics.commit();
}

fn drawCommands(layer: *const Layer, commands: []const Command) void {
    for (commands) |cmd| {
        switch (cmd.type) {
            .draw => if (cmd.end > cmd.start) doDraw(layer, cmd),
            .scissor => {
                const x, const y = .{ cmd.position.x, cmd.position.y };
                const w, const h = .{ cmd.size.x, cmd.size.y };
                sk.gfx.applyScissorRectf(x, y, w, h, true);
            },
        }
    }
}

fn doDraw(layer: *const Layer, cmd: Command) void {
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
