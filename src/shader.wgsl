struct Model {
    // 平移
    offset: vec2f,
};

@binding(0) @group(0) var<uniform> model: Model;

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
    let x = in.position.x + model.offset.x;
    // 翻转 y 轴
    let y = in.position.y - model.offset.y;
    out.position = vec4f(x, y, in.position.z, in.position.w);
    out.color = in.color;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    return in.color;
}