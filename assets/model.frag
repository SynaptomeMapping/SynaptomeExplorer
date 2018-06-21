#version 330 core

out vec4 color;
in vec4 normal;

uniform float g_ZSlice = 0.0;
uniform float g_TotalTime;

void main()
{
    float g_CulledAlpha = smoothstep( -0.75, 0.75, sin(3.0*g_TotalTime));
    float mult = max( step( g_ZSlice, normal.w), g_CulledAlpha);
    
    vec3 n = normalize(normal.xyz);
    float ndotl = dot(n, vec3(0,0,1));
    
    float value = 1.0 - abs(ndotl);
    color = vec4(value*mult);
    color.x = 1.0 - min(4*abs(g_ZSlice - normal.w),1.0);
} 