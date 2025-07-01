@vs vs
layout(binding=0) uniform vs_params {
    mat4 viewMatrix;
    vec4 textureVec;
};

in vec4 vertex_position;
in float vertex_rotation;
in vec2 vertex_size;
in vec2 vertex_pivot;
in vec4 vertex_texture;
in vec4 vertex_color;

const vec2 vertexArray[4] = {
    {0.0f, 0.0f},
    {1.0f, 0.0f},
    {0.0f, 1.0f},
    {1.0f, 1.0f},
};

out vec4 color;
out vec2 uv;

void main() {

    // 索引
    uint idx = uint(gl_VertexIndex) % 4;

    // 顶点
    vec2 P = vertex_pivot * vertex_size;
    float c = cos(vertex_rotation);
    float s = sin(vertex_rotation);
    mat2 R = mat2(c, s, -s, c);

    vec2 pos = R * (vertexArray[idx] * vertex_size - P) ;
    gl_Position = viewMatrix * vec4(pos + vertex_position.xy, 0, 1);

    // 颜色
    color = vertex_color;

    // 纹理
    vec2 minPix = vertex_texture.xy + vec2(0.5);
    vec2 maxPix = vertex_texture.zw - vec2(0.5);
    uv = mix(minPix, maxPix, vertexArray[idx]) * textureVec.xy;
}
@end

@fs fs

layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler smp;

in vec4 color;
in vec2 uv;
out vec4 frag_color;

void main() {
     frag_color = texture(sampler2D(tex, smp), uv) * color;
}
@end

@program quad vs fs