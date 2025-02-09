#pragma sokol @header const zm = @import("zmath")
#pragma sokol @ctype mat4 zm.Mat

@vs vs
layout(binding=0) uniform vs_params {
    mat4 vp;
};

in vec4 position;
in vec4 color0;

out vec4 color;

void main() {
    gl_Position = vp * position;
    color = color0;
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