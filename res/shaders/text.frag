#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;
uniform vec4 uColor = vec4(1.0, 1.0, 1.0, 1.0); // Default white color

void main() {
    // Sample the red channel from the texture (bitmap font)
    float texValue = texture(uTexture, TexCoord).r;
    
    // DEBUG: Output raw texture value to see what we're getting
    // If we see variation, the texture has data
    // If we see solid color, the texture is uniform or UV mapping is wrong
    FragColor = vec4(texValue, texValue, texValue, 1.0);
}