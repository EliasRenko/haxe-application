#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;
uniform vec4 uColor = vec4(1.0, 1.0, 1.0, 1.0); // Tint color

void main() {
    // Sample the red channel from the 1 BPP texture (stored as GL_RED format)
    float intensity = texture(uTexture, TexCoord).r;
    
    // For bitmap fonts like Nokia FC22, display as white text on black background
    // Since we see the characters should be white/light, use direct intensity
    FragColor = vec4(intensity, intensity, intensity, 1.0);
}