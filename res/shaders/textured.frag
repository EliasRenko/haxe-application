#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;

void main() {
    vec4 texColor = texture(uTexture, TexCoord);
    
    // Handle single-channel textures (fonts) by treating red channel as alpha
    // and setting RGB to white for proper font rendering
    if (texColor.g == 0.0 && texColor.b == 0.0) {
        // Single-channel texture (font) - use red channel as alpha, white as color
        FragColor = vec4(1.0, 1.0, 1.0, texColor.r);
    } else {
        // Regular multi-channel texture
        FragColor = texColor;
    }
}
