#version 330 core

in vec2 vWorldPos;
out vec4 FragColor;

// Light source world-space position.
uniform vec2 uLightPos;
// Falloff radius – attenuation reaches 0 at this distance.
uniform float uRadius;
// Light colour (rgb) and base intensity (a).
uniform vec4 uColor;

void main() {
    float dist        = length(vWorldPos - uLightPos);
    float attenuation = 1.0 - smoothstep(0.0, uRadius, dist);
    FragColor = vec4(uColor.rgb, uColor.a * attenuation);
}
