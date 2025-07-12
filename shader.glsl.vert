#version 460

layout(set=1,binding=0) uniform UBO {
    mat4 mvp;
};

layout(location=0) in vec3 in_position; // Vertex position input

void main()
{
    gl_Position = mvp * vec4(in_position,1); // Apply the projection matrix
}