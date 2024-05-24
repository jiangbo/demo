struct VertexInput {
    @builtin(position) position: vec4f,
};

struct VertexOutput {
    @builtin(position) position: vec4f,
};

@group(0) @binding(0) var<uniform> mvp: mat4x4f;

@vertex
fn vs_main(in : VertexInput) -> VertexOutput {

    let pos = array(
          // 1st triangle
          vec2f( 0.0,  0.0),  // center
          vec2f( 1.0,  0.0),  // right, center
          vec2f( 0.0,  1.0),  // center, top

          // 2st triangle
          vec2f( 0.0,  1.0),  // center, top
          vec2f( 1.0,  0.0),  // right, center
          vec2f( 1.0,  1.0),  // right, top
        );

    var out: VertexOutput;

    out.position = mvp * in.position;
    out.texcoord = xy;


//      var output : VertexOutput;
//   output.Position = uniforms.modelViewProjectionMatrix * position;
//   output.fragUV = uv;
//   output.fragPosition = 0.5 * (position + vec4(1.0, 1.0, 1.0, 1.0));
//   return output;


    return out;
}

@group(0) @binding(0) var ourSampler: sampler;
@group(0) @binding(1) var ourTexture: texture_2d<f32>;

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4f {
    return textureSample(ourTexture, ourSampler, in.texcoord);
}
