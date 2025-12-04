const std = @import("std");

const gpu = @import("gpu.zig");
const math = @import("math.zig");
const shader = @import("shader/quad.glsl.zig");
const window = @import("window.zig");
const font = @import("font.zig");

const Texture = gpu.Texture;
const Vector = math.Vector;
const Vector2 = math.Vector2;
const Rect = math.Rect;
const Color = math.Vector4;
pub const Vertex = gpu.QuadVertex;

pub var mode: enum { world, local } = .world;
pub var position: math.Vector = .zero;
pub var whiteTexture: gpu.Texture = undefined;

var startDraw: bool = false;

var bindGroup: gpu.BindGroup = .{};
var pipeline: gpu.RenderPipeline = undefined;

var gpuBuffer: gpu.Buffer = undefined;
var vertexBuffer: std.ArrayList(gpu.QuadVertex) = .empty;
var usingTexture: gpu.Texture = .{ .view = .{} };
const DrawCommand = struct { scale: Vector2 = .one, texture: Texture };
const CommandUnion = union(enum) { draw: DrawCommand, scissor: Rect };
const Command = struct { start: u32 = 0, end: u32, cmd: CommandUnion };
var commandArray: [16]Command = undefined;
var commandIndex: u32 = 0;

pub fn init(buffer: []Vertex) void {
    gpuBuffer = gpu.createBuffer(.{
        .size = @sizeOf(Vertex) * buffer.len,
        .usage = .{ .stream_update = true },
    });
    vertexBuffer = .initBuffer(buffer);

    const shaderDesc = shader.quadShaderDesc(gpu.queryBackend());
    pipeline = gpu.createQuadPipeline(shaderDesc);
}

pub fn initWithWhiteTexture(buffer: []Vertex) void {
    init(buffer);
    const data: [64]u8 = [1]u8{0xFF} ** 64;
    whiteTexture = gpu.createTexture(.init(4, 4), &data);
}

pub fn toWorld(windowPosition: Vector) Vector {
    return windowPosition.add(position);
}

pub fn toWindow(worldPosition: Vector) Vector {
    return worldPosition.sub(position);
}

pub fn beginDraw(color: gpu.Color) void {
    gpu.begin(color);
    startDraw = true;
    commandIndex = 0;
    vertexBuffer.clearRetainingCapacity();
    font.beginDraw();
}

pub fn debugDraw(area: math.Rect) void {
    drawRect(area, .{ .x = 1, .z = 1, .w = 0.4 });
}

pub fn draw(texture: gpu.Texture, pos: math.Vector) void {
    drawOption(texture, pos, .{});
}

pub fn drawFlipX(texture: Texture, pos: Vector, flipX: bool) void {
    drawOption(texture, pos, .{ .flipX = flipX });
}

pub fn drawRectLine(start: Vector, end: Vector, color: Color) void {
    if (start.x == end.x) {
        drawRect(.init(start, .init(end.y - start.y, 1)), color);
    } else if (start.y == end.y) {
        drawRect(.init(start, .init(1, end.x - start.x)), color);
    }
}

pub fn drawRectBorder(area: Rect, width: f32, color: Color) void {
    drawRect(.init(area.min, .init(area.size.x, width)), color); // 上
    var start = area.min.addY(area.size.y - width);
    drawRect(.init(start, .init(area.size.x, width)), color); // 下
    const size: Vector2 = .init(width, area.size.y - 2 * width);
    drawRect(.init(area.min.addY(width), size), color); // 左
    start = area.min.addXY(area.size.x - width, width);
    drawRect(.init(start, size), color); // 右
}

pub fn drawRect(area: math.Rect, color: Color) void {
    drawOption(whiteTexture, area.min, .{
        .size = area.size,
        .color = color,
    });
}

pub const Option = struct {
    size: ?Vector2 = null, // 大小
    pivot: Vector2 = .zero, // 旋转中心
    radian: f32 = 0, // 旋转角度
    color: Color = .one, // 颜色
    flipX: bool = false, // 是否水平翻转
};
pub fn drawOption(texture: Texture, pos: Vector, option: Option) void {
    var textureVector: math.Vector4 = texture.area.toVector4();
    if (option.flipX) {
        std.mem.swap(f32, &textureVector.x, &textureVector.z);
    }

    const size = option.size orelse texture.size();
    var temp = pos.sub(size.mul(option.pivot));
    if (mode == .local) temp = temp.add(position);

    drawVertices(texture, &.{Vertex{
        .position = temp.toVector3(0),
        .radian = option.radian,
        .size = size,
        .texture = textureVector,
        .color = option.color,
    }});
}

pub fn drawVertices(texture: Texture, vertex: []const Vertex) void {
    if (!startDraw) @panic("need begin draw");

    // 无论怎么样都加入顶点缓冲，但是放到最后来加，判断是不是第一次更清晰
    defer vertexBuffer.appendSliceAssumeCapacity(vertex);

    if (vertexBuffer.items.len == 0) { // 第一次绘制
        const cmd = CommandUnion{ .draw = .{ .texture = texture } };
        commandArray[commandIndex] = .{ .end = 0, .cmd = cmd };
        usingTexture = texture;
        return;
    }

    if (texture.view.id != usingTexture.view.id) {
        // 不是第一次的情况下，只有纹理不一致才开始新的绘制命令
        usingTexture = texture;
        startNewDrawCommand();
    }
}

pub fn encodeScaleCommand(scale: Vector2) void {
    commandArray[commandIndex].cmd.draw.scale = scale;
    startNewDrawCommand();
}

pub fn startNewDrawCommand() void {
    encodeCommand(.{ .draw = .{ .texture = usingTexture } });
}

pub fn encodeCommand(cmd: CommandUnion) void {
    const index: u32 = @intCast(vertexBuffer.items.len);
    commandArray[commandIndex].end = index;
    commandIndex += 1;
    commandArray[commandIndex].cmd = cmd;
    commandArray[commandIndex].start = index;
}

pub fn endDraw() void {
    startDraw = false;
    font.flush();
    defer gpu.end();
    if (vertexBuffer.items.len == 0) return; // 没需要绘制的东西

    commandArray[commandIndex].end = @intCast(vertexBuffer.items.len);
    gpu.updateBuffer(gpuBuffer, vertexBuffer.items);
    var drawCmd: DrawCommand = undefined;
    for (commandArray[0 .. commandIndex + 1]) |cmd| {
        switch (cmd.cmd) {
            .draw => |d| drawCmd = d,
            .scissor => |area| gpu.scissor(area),
        }
        drawInstanced(cmd, drawCmd);
    }
}

pub fn scissor(area: math.Rect) void {
    const min = area.min.mul(window.ratio);
    const size = area.size.mul(window.ratio);
    encodeCommand(.{ .scissor = .{ .min = min, .size = size } });
}
pub fn resetScissor() void {
    encodeCommand(.{ .scissor = .fromMax(.zero, window.clientSize) });
}

fn drawInstanced(cmd: Command, drawCmd: DrawCommand) void {
    // 绑定流水线
    gpu.setPipeline(pipeline);

    // 处理 uniform 变量
    const x, const y = .{ window.logicSize.x, window.logicSize.y };
    const orth = math.Matrix.orthographic(x, y, 0, 1);
    const pos = position.scale(-1).toVector3(0);
    const translate = math.Matrix.translateVec(pos);
    const scaleMatrix = math.Matrix.scaleVec(drawCmd.scale.toVector3(1));
    const view = math.Matrix.mul(scaleMatrix, translate);

    const size = gpu.queryTextureSize(drawCmd.texture);
    gpu.setUniform(shader.UB_vs_params, .{
        .viewMatrix = math.Matrix.mul(orth, view).mat,
        .textureVec = [4]f32{ 1 / size.x, 1 / size.y, 1, 1 },
    });

    // 绑定组
    bindGroup.setTexture(drawCmd.texture);
    bindGroup.setVertexBuffer(gpuBuffer);
    bindGroup.setVertexOffset(cmd.start * @sizeOf(Vertex));
    bindGroup.setSampler(gpu.nearestSampler);

    gpu.setBindGroup(bindGroup);

    // 绘制
    gpu.drawInstanced(cmd.end - cmd.start);
}

pub const frameStats = gpu.frameStats;
pub const queryFrameStats = gpu.queryFrameStats;
pub const queryBackend = gpu.queryBackend;
pub const drawNumber = font.drawNumber;
pub const drawColorNumber = font.drawColorNumber;
pub const drawText = font.drawText;
pub const drawColorText = font.drawColorText;
pub const drawTextOptions = font.drawTextOptions;
pub const flushText = font.flush;

pub fn imageDrawCount() usize {
    return commandIndex + 1;
}

pub fn textDrawCount() usize {
    return font.totalDrawCount;
}
