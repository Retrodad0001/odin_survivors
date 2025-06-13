#version 460


void main()
{
    if (gl_VertexIndex == 0) {
        // If this is the first vertex, set the position to a specific value
        gl_Position = vec4(-0.5, -0.5, 0.0, 1.0); // Example position
    }
    else if (gl_VertexIndex == 1) {
        // If this is the second vertex, set the position to another specific value
        gl_Position = vec4(0.5, -0.5, 0.0, 1.0); // Example position
    }
    else if (gl_VertexIndex == 2) {
        // If this is the third vertex, set the position to yet another specific value
        gl_Position = vec4(0.0, 0.5, 0.0, 1.0); // Example position
    }
    

    
}