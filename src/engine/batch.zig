const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const graphics = @import("graphics.zig");
const camera = @import("camera.zig");
const assets = @import("assets.zig");

const Image = graphics.Image;
const ImageId = graphics.ImageId;
const Color = graphics.Color;
const Vector2 = math.Vector2;
const Matrix = math.Matrix;
const Texture = gpu.Texture;

pub var pipeline: gpu.RenderPipeline = undefined;
var gpuBuffer: gpu.Buffer = undefined;
var vertexBuffer: std.ArrayList(Vertex) = .empty;

pub var whiteImage: graphics.ImageId = undefined;

const DrawCommand = struct {
    position: Vector2 = .zero, // 位置
    scale: Vector2 = .one, // 缩放
    texture: Texture = .{}, // 纹理
};
const CommandUnion = union(enum) { draw: DrawCommand, scissor: math.Rect };
const Command = struct { start: u32 = 0, end: u32, cmd: CommandUnion };
var commands: [16]Command = undefined;
var commandIndex: u32 = 0;
var windowSize: Vector2 = undefined;

pub const Vertex = extern struct {
    position: math.Vector2, // 顶点坐标
    radian: f32 = 0, // 旋转弧度
    padding: f32 = 1,
    size: math.Vector2, // 大小
    pivot: math.Vector2 = .zero, // 旋转中心
    texture: math.Vector4, // 纹理坐标
    color: graphics.Color = .white, // 顶点颜色
};

pub fn init(size: Vector2, buffer: []Vertex) void {
    windowSize = size;

    gpuBuffer = gpu.createBuffer(.{
        .size = @sizeOf(Vertex) * buffer.len,
        .usage = .{ .stream_update = true },
    });
    vertexBuffer = .initBuffer(buffer);

    const shaderDesc = shader.quadShaderDesc(gpu.queryBackend());
    pipeline = createQuadPipeline(shaderDesc);

    camera.worldSize = size; // 初始化摄像机的世界大小
}

pub fn initWithWhiteTexture(size: Vector2, buffer: []Vertex) void {
    init(size, buffer);
    whiteImage = graphics.createWhiteImage("engine/white");
}

pub const Option = struct {
    size: ?Vector2 = null, // 大小
    scale: Vector2 = .one, // 缩放
    anchor: Vector2 = .zero, // 锚点
    pivot: Vector2 = .center, // 旋转中心
    radian: f32 = 0, // 旋转弧度
    color: graphics.Color = .white, // 颜色
    flipX: bool = false, // 水平翻转
};

pub fn beginDraw(color: graphics.Color) void {
    graphics.beginDraw(color);
    commandIndex = 0;
    commands[commandIndex].cmd.draw = .{};
    vertexBuffer.clearRetainingCapacity();
}

pub fn endDraw() void {
    defer gpu.end();
    if (vertexBuffer.items.len == 0) return; // 没需要绘制的东西

    commands[commandIndex].end = @intCast(vertexBuffer.items.len);
    gpu.updateBuffer(gpuBuffer, vertexBuffer.items);
    for (commands[0 .. commandIndex + 1]) |cmd| {
        switch (cmd.cmd) {
            .draw => |drawCmd| doDraw(cmd, drawCmd),
            .scissor => |area| gpu.scissor(area),
        }
    }
}

pub fn debugDraw(area: math.Rect) void {
    drawRect(area, .{ .color = .{ .x = 1, .z = 1, .w = 0.4 } });
}

pub fn draw(image: ImageId, pos: math.Vector2) void {
    drawImageId(image, pos, .{});
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

    drawImageId(graphics.whiteImage, .init(start.x, y), .{
        .size = .init(vector.length(), option.width),
        .color = option.color,
        .radian = vector.atan2(),
        .pivot = .init(0, 0.5),
    });
}

pub fn drawRectBorder(area: math.Rect, width: f32, c: Color) void {
    const color = RectOption{ .color = c };
    drawRect(.init(area.min, .xy(area.size.x, width)), color); // 上
    var start = area.min.addY(area.size.y - width);
    drawRect(.init(start, .xy(area.size.x, width)), color); // 下
    const size: Vector2 = .xy(width, area.size.y - 2 * width);
    drawRect(.init(area.min.addY(width), size), color); // 左
    start = area.min.addXY(area.size.x - width, width);
    drawRect(.init(start, size), color); // 右
}

pub const RectOption = struct { color: Color = .white, radian: f32 = 0 };
pub fn drawRect(area: math.Rect, option: RectOption) void {
    drawImageId(whiteImage, area.min, .{
        .size = area.size,
        .color = option.color,
        .radian = option.radian,
    });
}

pub fn drawImageId(id: ImageId, pos: Vector2, option: Option) void {
    drawImage(assets.getImage(id), pos, option);
}

pub fn drawImage(image: Image, pos: Vector2, option: Option) void {
    var worldPos = pos;
    if (camera.modeEnum == .window) {
        worldPos = camera.position.add(pos);
    }

    const size = (option.size orelse image.area.size);
    const scaledSize = size.mul(option.scale);

    var imageVector: math.Vector4 = image.area.toVector4();
    if (option.flipX) {
        imageVector.x += imageVector.z;
        imageVector.z = -imageVector.z;
    }

    drawVertices(image.texture, &.{Vertex{
        .position = worldPos.sub(scaledSize.mul(option.anchor)),
        .radian = option.radian,
        .size = scaledSize,
        .pivot = option.pivot,
        .texture = imageVector,
        .color = option.color,
    }});
}

pub fn drawVertices(texture: Texture, vertex: []const Vertex) void {
    const drawCommand = &commands[commandIndex].cmd.draw;
    if (drawCommand.texture.id == 0) {
        drawCommand.texture = texture; // 还没有绘制任何纹理
    } else if (texture.id != drawCommand.texture.id) {
        startNewDrawCommand(); // 纹理改变，开始新的命令
        commands[commandIndex].cmd.draw.texture = texture;
    }

    vertexBuffer.appendSliceAssumeCapacity(vertex);
}

pub fn startNewDrawCommand() void {
    encodeCommand(.{ .draw = .{} });
}

pub fn setScale(scale: Vector2) void {
    commands[commandIndex].cmd.draw.scale = scale;
}

pub fn encodeCommand(cmd: CommandUnion) void {
    const index: u32 = @intCast(vertexBuffer.items.len);
    commands[commandIndex].end = index;
    commandIndex += 1;
    commands[commandIndex].cmd = cmd;
    commands[commandIndex].start = index;
}

fn doDraw(cmd: Command, drawCmd: DrawCommand) void {
    // 绑定流水线
    gpu.setPipeline(pipeline);

    // 处理 uniform 变量
    const x, const y = .{ windowSize.x, windowSize.y };
    const orth = math.Matrix.orthographic(x, y, 0, 1);
    const pos = camera.position.scale(-1).toVector3(0);
    const translate = math.Matrix.translateVec(pos);
    const scaleMatrix = math.Matrix.scaleVec(drawCmd.scale.toVector3(1));
    const view = math.Matrix.mul(scaleMatrix, translate);

    const size = gpu.queryTextureSize(drawCmd.texture);
    gpu.setUniform(shader.UB_vs_params, .{
        .viewMatrix = math.Matrix.mul(orth, view).mat,
        .textureVec = [4]f32{ 1 / size.x, 1 / size.y, 1, 1 },
    });

    // 绑定组
    var bindGroup: gpu.BindGroup = .{};
    bindGroup.setTexture(drawCmd.texture);
    bindGroup.setVertexBuffer(gpuBuffer);
    bindGroup.setVertexOffset(cmd.start * @sizeOf(Vertex));
    bindGroup.setSampler(gpu.nearestSampler);
    gpu.setBindGroup(bindGroup);

    // 绘制
    gpu.drawInstanced(cmd.end - cmd.start);
}

pub fn createQuadPipeline(shaderDesc: gpu.ShaderDesc) gpu.RenderPipeline {
    var vertexLayout = gpu.VertexLayoutState{};

    vertexLayout.attrs[0].format = .FLOAT2;
    vertexLayout.attrs[1].format = .FLOAT;
    vertexLayout.attrs[2].format = .FLOAT;
    vertexLayout.attrs[3].format = .FLOAT2;
    vertexLayout.attrs[4].format = .FLOAT2;
    vertexLayout.attrs[5].format = .FLOAT4;
    vertexLayout.attrs[6].format = .FLOAT4;
    vertexLayout.buffers[0].step_func = .PER_INSTANCE;

    return gpu.createPipeline(.{
        .shader = gpu.createShader(shaderDesc),
        .layout = vertexLayout,
        .primitive_type = .TRIANGLE_STRIP,
        .colors = init: {
            var c: [8]gpu.ColorTargetState = @splat(.{});
            c[0] = .{ .blend = .{
                .enabled = true,
                .src_factor_rgb = .SRC_ALPHA,
                .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
            } };
            break :init c;
        },
    });
}

pub fn imageDrawCount() usize {
    return commandIndex + 1;
}
