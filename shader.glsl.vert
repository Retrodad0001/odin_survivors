#version 460

layout(set=1,binding=0) uniform UBO {
    mat4 mvp;
};

layout(location=0) in vec3 in_position; // Vertex position input
layout(location=1) in vec4 in_color; // Vertex color input

layout(location=0) out vec4 out_color; // Output color to fragment shader

void main()
{
    gl_Position = mvp * vec4(in_position,1);
    out_color = in_color; // Apply the projection matrix
}