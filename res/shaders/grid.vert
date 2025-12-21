#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;

out vec2 fragPos;
out vec2 texCoord;

uniform mat4 uMatrix;

void main() {
    gl_Position = uMatrix * vec4(aPos, 1.0);
    
    // Pass world space position to fragment shader for grid calculation
    fragPos = aPos.xy;
    texCoord = aTexCoord;
}
