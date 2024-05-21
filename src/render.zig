const std = @import("std");
const mach = @import("mach");
const zlm = @import("zlm");

pub const RenderContext = struct {
    vertexBuffer: *mach.gpu.Buffer,
    vertexCount: u32,
    depthView: *mach.gpu.TextureView,
    pipeline: *mach.gpu.RenderPipeline,
    uniforms: [objectNumber]Uniforms,

    pub fn release(self: *RenderContext) void {
        self.vertexBuffer.release();
        for (&self.uniforms) |*value| value.release();
        self.pipeline.release();
    }
};

pub const Uniforms = struct {
    buffer: *mach.gpu.Buffer,
    bindGroup: *mach.gpu.BindGroup,

    pub fn release(self: *Uniforms) void {
        self.buffer.release();
        self.bindGroup.release();
    }
};

pub const positions = [_]f32{
    // left column
    -50, 75,  15,
    -20, 75,  15,
    -50, -75, 15,
    -20, -75, 15,

    // top rung
    -20, 75,  15,
    50,  75,  15,
    -20, 45,  15,
    50,  45,  15,

    // middle rung
    -20, 15,  15,
    20,  15,  15,
    -20, -15, 15,
    20,  -15, 15,

    // left column back
    -50, 75,  -15,
    -20, 75,  -15,
    -50, -75, -15,
    -20, -75, -15,

    // top rung back
    -20, 75,  -15,
    50,  75,  -15,
    -20, 45,  -15,
    50,  45,  -15,

    // middle rung back
    -20, 15,  -15,
    20,  15,  -15,
    -20, -15, -15,
    20,  -15, -15,
};

pub const indices = [_]u32{
    0, 2, 1, 2, 3, 1, // left column
    4, 6, 5, 6, 7, 5, // top run
    8, 10, 9, 10, 11, 9, // middle run
    12, 13, 14, 14, 13, 15, // left column back
    16, 17, 18, 18, 17, 19, // top run back
    20, 21, 22, 22, 21, 23, // middle run back
    0, 5, 12, 12, 5, 17, // top
    5, 7, 17, 17, 7, 19, // top rung right
    6, 18, 7, 18, 19, 7, // top rung bottom
    6, 8, 18, 18, 8, 20, // between top and middle rung
    8, 9, 20, 20, 9, 21, // middle rung top
    9, 11, 21, 21, 11, 23, // middle rung right
    10, 22, 11, 22, 23, 11, // middle rung bottom
    10, 3, 22, 22, 3, 15, // stem right
    2, 14, 3, 14, 15, 3, // bottom
    0, 12, 2, 12, 14, 2, // left
};

const quadColors = [_]u8{
    200, 70, 120, // left column front
    200, 70, 120, // top rung front
    200, 70, 120, // middle rung front
    80, 70, 200, // left column back
    80, 70, 200, // top rung back
    80, 70, 200, // middle rung back
    70, 200, 210, // top
    160, 160, 220, // top rung right
    90, 130, 110, // top rung bottom
    200, 200, 70, // between top and middle rung
    210, 100, 70, // middle rung top
    210, 160, 70, // middle rung right
    70, 180, 210, // middle rung bottom
    100, 70, 210, // stem right
    76, 210, 100, // bottom
    140, 210, 80, // left
};

var vertexData: [indices.len * 4]f32 = undefined;
var colorData: [*]u8 = @as([*]u8, @ptrCast(&vertexData));

const objectNumber = 5;

pub fn createRenderPipeline() RenderContext {
    const device = mach.core.device;

    for (0..indices.len) |i| {
        const positionNdx = indices[i] * 3;
        const position = positions[positionNdx .. positionNdx + 3];
        @memcpy(vertexData[i * 4 ..][0..3], position);

        const quadNdx = (i / 6 | 0) * 3;
        const color = quadColors[quadNdx .. quadNdx + 3];
        @memcpy(colorData[i * 16 + 12 ..][0..3], color);
        colorData[i * 16 + 15] = 255; // set A
    }

    // 编译 shader
    const source = @embedFile("shader.wgsl");
    const module = device.createShaderModuleWGSL("shader.wgsl", source);
    defer module.release();

    // 顶点缓冲区
    const vertexBuffer = device.createBuffer(&.{
        .label = "vertex",
        .usage = .{ .copy_dst = true, .vertex = true },
        .size = @sizeOf(@TypeOf(vertexData)),
    });

    // 将 CPU 内存中的数据复制到 GPU 内存中
    mach.core.queue.writeBuffer(vertexBuffer, 0, &vertexData);

    const vertexLayout = mach.gpu.VertexBufferLayout.init(.{
        .array_stride = @sizeOf(f32) * 4,
        .attributes = &.{
            .{ .shader_location = 0, .offset = 0, .format = .float32x3 }, // position
            .{ .shader_location = 1, .offset = 12, .format = .unorm8x4 }, // color
        },
    });

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
        .vertex = vertex,
        .primitive = .{ .cull_mode = .back },
        .depth_stencil = &.{
            .depth_write_enabled = .true,
            .depth_compare = .less,
            .format = .depth24_plus,
        },
    };

    const depthTextureDescriptor = mach.gpu.Texture.Descriptor.init(.{
        .format = .depth24_plus,
        .size = .{ .width = 640, .height = 480 },
        .usage = .{ .render_attachment = true },
        .view_formats = &.{.depth24_plus},
    });
    const depthTexture = device.createTexture(&depthTextureDescriptor);
    defer depthTexture.release();

    const depthDescriptor = mach.gpu.TextureView.Descriptor{
        .aspect = .depth_only,
        .array_layer_count = 1,
        .mip_level_count = 1,
        .dimension = .dimension_2d,
        .format = .depth24_plus,
    };
    const pipeline = device.createRenderPipeline(&descriptor);
    var objectInfos: [objectNumber]Uniforms = undefined;
    for (0..objectNumber) |i| {
        // matrix
        const uniformBufferSize = 16 * 4;
        const uniformBuffer = device.createBuffer(&.{
            .label = "uniforms",
            .size = uniformBufferSize,
            .usage = .{ .uniform = true, .copy_dst = true },
        });
        const Entry = mach.gpu.BindGroup.Entry;
        const bindGroup = device.createBindGroup(
            &mach.gpu.BindGroup.Descriptor.init(.{
                .label = "bind group for object",
                .layout = pipeline.getBindGroupLayout(0),
                .entries = &.{
                    Entry.buffer(0, uniformBuffer, 0, uniformBufferSize),
                },
            }),
        );
        objectInfos[i] = .{
            .bindGroup = bindGroup,
            .buffer = uniformBuffer,
        };
    }

    return .{
        .vertexBuffer = vertexBuffer,
        .vertexCount = indices.len,
        .depthView = depthTexture.createView(&depthDescriptor),
        .pipeline = pipeline,
        .uniforms = objectInfos,
    };
}
