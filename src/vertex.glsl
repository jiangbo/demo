#version 330 core

layout(location = 0) in vec3 vertexPosition; // 顶点位置

void main()
{
    gl_Position = vec4(vertexPosition, 1.0); // 设置顶点位置
}
