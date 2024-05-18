@binding(0) @group(0) var<uniform> model: mat3x3f;

struct VertexInput {
    @location(0) position: vec4f,
};

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) color: vec4f,
};

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    let xy = (model * vec3f(in.position.xy, 1)).xy;
    out.position = vec4f(xy, 0.0, 1.0);
    out.color = vec4f(0, 1, 0, 1);
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    return in.color;
}