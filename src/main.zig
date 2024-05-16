const std = @import("std");

const mach = @import("mach");

pub const App = @This();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var renderPipeline: mach.gpu.RenderPipeline = undefined;

pub fn init(_: *App) !void {
    try mach.core.init(.{});
    // 设置帧率
    mach.core.setFrameRateLimit(30);
    mach.core.setInputFrequency(30);

    const device = mach.core.device;

    const red = 0xFF0000FF;
    const yellow = 0xFFFF00FF;
    const blue = 0x0000FFFF;

    const textureData = [_]u32{
        blue, red,    red,    red,    red, //
        red,  yellow, yellow, yellow, red,
        red,  yellow, red,    red,    red,
        red,  yellow, yellow, red,    red,
        red,  yellow, red,    red,    red,
        red,  yellow, red,    red,    red,
        red,  red,    red,    red,    red,
    };

    const size = mach.gpu.Extent3D{ .width = 5, .height = 7 };
    const texture = device.createTexture(.{
        .label = "F texutre",
        .size = .{ .width = size.width, .height = size.height },
        .format = .rgba8_unorm,
        .usage = .{ .texture_binding = true, .copy_dst = true },
    });

    device.getQueue().writeTexture(&texture, &.{
        .bytes_per_row = @sizeOf(u32) * 5,
    }, &size, &textureData);

    const sampler = device.createSampler();

    const bindGroup = device.createBindGroup({
    layout: pipeline.getBindGroupLayout(0),
    entries: [
      { binding: 0, resource: sampler },
      { binding: 1, resource: texture.createView() },
    ],
  });

  const renderPassDescriptor = {
    label: 'our basic canvas renderPass',
    colorAttachments: [
      {
        // view: <- to be filled out when we render
        clearValue: [0.3, 0.3, 0.3, 1],
        loadOp: 'clear',
        storeOp: 'store',
      },
    ],
  };

    // 输出 buffer
    const resultBuffer = device.createBuffer(&.{
        .label = "result buffer",
        .size = @sizeOf(@TypeOf(input)),
        .usage = .{ .map_read = true, .copy_dst = true },
    });
    defer resultBuffer.release();

    // 提交指令
    const encoder = device.createCommandEncoder(null);
    const pass = encoder.beginComputePass(null);

    pass.setPipeline(re);
    pass.setBindGroup(0, bindGroup, &.{});
    pass.dispatchWorkgroups(input.len, 1, 1);
    pass.end();
    pass.release();

    encoder.copyBufferToBuffer(workBuffer, 0, resultBuffer, 0, size);

    var commandBuffer = encoder.finish(null);
    encoder.release();

    mach.core.queue.submit(&[_]*mach.gpu.CommandBuffer{commandBuffer});
    commandBuffer.release();

    // 异步得到返回结果
    const Status = mach.gpu.Buffer.MapAsyncStatus;
    var response: Status = undefined;
    resultBuffer.mapAsync(.{ .read = true }, 0, size, &response, struct {
        pub inline fn callback(ctx: *Status, status: Status) void {
            ctx.* = status;
        }
    }.callback);

    while (true) {
        if (response == .success) break;
        mach.core.device.tick();
    }

    const result = resultBuffer.getConstMappedRange(f32, 0, input.len);
    for (result.?) |v| {
        std.debug.print("{d} ", .{v});
    }
    std.debug.print("\n", .{});
    resultBuffer.unmap();
}

fn createRenderPipeline() *mach.gpu.RenderPipeline {
    const device = mach.core.device;

    // 编译 shader
    const source = @embedFile("shader/shader.wgsl");
    const module = device.createShaderModuleWGSL("shader.wgsl", source);
    defer module.release();

    // 顶点的布局
    const vertexLayout = mach.gpu.VertexBufferLayout.init(.{
        // 前面两个是坐标，后面三个是颜色
        .array_stride = @sizeOf(f32) * 6,
        .attributes = &.{
            // 第一个是顶点坐标，偏移从 0 开始
            .{ .format = .float32x3, .offset = 0, .shader_location = 0 },
            // 第二个是颜色，偏移从 3 开始，shader_location 对应 WGSL 中的 location 位置
            .{ .format = .float32x3, .offset = @sizeOf(f32) * 3, .shader_location = 1 },
        },
    });

    // 顶点着色器状态
    const vertex = mach.gpu.VertexState.init(.{
        .module = module,
        .entry_point = "vs_main",
        .buffers = &.{vertexLayout},
    });

    // 片段着色器状态
    const fragment = mach.gpu.FragmentState.init(.{
        .module = module,
        .entry_point = "fs_main",
        .targets = &.{.{ .format = mach.core.descriptor.format }},
    });

    // 创建渲染管线
    const descriptor = mach.gpu.RenderPipeline.Descriptor{
        .fragment = &fragment,
        .vertex = &vertex,
    };
    return device.createRenderPipeline(&descriptor);
}

pub fn deinit(app: *App) void {
    _ = app;
    mach.core.deinit();
    _ = gpa.deinit();
}

pub fn update(_: *App) !bool {
    return true;
}
