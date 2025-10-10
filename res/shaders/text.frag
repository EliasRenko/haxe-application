#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;
uniform vec4 uColor = vec4(1.0, 1.0, 1.0, 1.0); // Default white color

void main() {
    // Sample the red channel from the texture (bitmap font)
    float texValue = texture(uTexture, TexCoord).r;
    
    // Show the raw texture value scaled up so we can see small values
    // If all values are 0, we'll see black
    // If there are small values, we'll see dark gray
    // If values are 1.0, we'll see white
    FragColor = vec4(texValue * 4.0, texValue * 4.0, texValue * 4.0, 1.0);
}