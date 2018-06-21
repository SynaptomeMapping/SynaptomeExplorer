#version 330 core

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_normal;

uniform mat4 g_ModelView;
uniform mat4 g_Projection;

out vec4 normal;

void main()
{
    gl_Position = (g_Projection * g_ModelView) * vec4(in_position,1.0);
    normal = g_ModelView * vec4( in_normal, 0.0);
    normal.w = in_position.y;
}