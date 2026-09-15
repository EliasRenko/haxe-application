#version 330 core
in vec2 TexCoord;
out vec4 FragColor;
uniform sampler2D uScreenTexture;

void main() {
    vec4 color = texture(uScreenTexture, TexCoord);
    
    // Scanline effect
    float scanline = sin(TexCoord.y * 480.0 * 2.0) * 0.1 + 0.9;
    
    // Vignette effect
    vec2 center = TexCoord - 0.5;
    float vignette = 1.0 - dot(center, center) * 0.5;
    
    FragColor = vec4(color.rgb * scanline * vignette, color.a);
}
