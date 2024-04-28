#version 330 core

layout(location = 0) in vec2 vertex; // 顶点位置
layout(location = 1) in vec2 texCoords; // 顶点纹理坐标
uniform mat4 model;
uniform mat4 projection;
out vec2 uv;


void main()
{
    gl_Position = projection * model * vec4(vertex, 0.0, 1.0);
    uv = texCoords;
}
