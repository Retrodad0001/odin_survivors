#version 460

layout(location = 0) in vec4 in_color;
layout(location = 1) in vec2 in_uv;

layout(location = 0) out vec4 frag_color;

layout(set=2,binding=0) uniform sampler2D texture_sampler; //2 is needed for SDL3

void main() {
    frag_color =  texture(texture_sampler,in_uv) * in_color; 
}