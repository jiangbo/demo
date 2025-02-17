#pragma sokol @header const zm = @import("zmath")
#pragma sokol @ctype mat4 zm.Mat
#pragma sokol @ctype vec4 zm.Vec

@vs vs
layout(binding=0) uniform vs_params {
    mat4 mvp;
};

struct sb_vertex {
    vec4 pos;
    vec4 color;
};

struct sb_instance {
    vec4 pos;
};

layout(binding=0) readonly buffer vertices {
    sb_vertex vtx[];
};

layout(binding=1) readonly buffer instances {
    sb_instance inst[];
};

out vec4 color;

void main() {
    const vec4 pos = vtx[gl_VertexIndex].pos + inst[gl_InstanceIndex].pos;
    gl_Position = mvp * pos;
    color = vtx[gl_VertexIndex].color;
}
@end

@fs fs
in vec4 color;
out vec4 frag_color;
void main() {
    frag_color = color;
}
@end

@program test vs fs