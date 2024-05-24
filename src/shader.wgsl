struct VertexInput{
    @location(0) position : vec4<f32>
}

struct VertexOutput {
     @builtin(position) position : vec4<f32>,
     @location(0) fragUV : vec2<f32>,
     @location(1) fragPosition: vec4<f32>,
}

@group(0) @binding(0) var<uniform> ubo : mat4x4<f32>;

@vertex
fn vs_main(in: VertexInput) -> VertexOutput {
     var out : VertexOutput;
     out.position = in.position * ubo;
     out.fragUV = uv;
     out.fragPosition = 0.5 * (in.position + vec4<f32>(1.0, 1.0, 1.0, 1.0));
     return out;
}

@fragment fn frag_main(
    @location(0) fragUV: vec2<f32>,
    @location(1) fragPosition: vec4<f32>
) -> @location(0) vec4<f32> {
    return fragPosition;
}