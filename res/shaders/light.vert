#version 330 core

layout(location = 0) in vec3 aPosition;

uniform mat4 uMatrix;

// Pass world-space XY to the fragment shader for distance-based attenuation.
out vec2 vWorldPos;

void main() {
    gl_Position = uMatrix * vec4(aPosition, 1.0);
    vWorldPos = aPosition.xy;
}
