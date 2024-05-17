@binding(0) @group(0) var<uniform> model: mat3x3f;

struct VertexInput {
    @location(0) position: vec4f,
    @location(1) color: vec4f,
};

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) color: vec4f,
};

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    let pos = (model * vec3(in.position.xy, 1));
    // 翻转 Y 轴，来适合屏幕坐标系
    out.position = vec4f(pos.x, -pos.y, pos.z, in.position.w);
    out.color = in.color;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    return in.color;
}