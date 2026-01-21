#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;
uniform vec4 uColor = vec4(1.0, 1.0, 1.0, 1.0); // Tint color

void main() {
    // Sample the texture
    vec4 texSample = texture(uTexture, TexCoord);
    
    // For 1BPP fonts (GL_RED), use red channel
    // For RGBA baked fonts (white RGB + alpha), use alpha channel
    // Check if texture has meaningful alpha (baked fonts have white RGB, so r ~= 1.0)
    float intensity = (texSample.r > 0.99) ? texSample.a : texSample.r;
    
    // Use premultiplied alpha: multiply both color and alpha by intensity
    // This ensures transparent areas contribute no color
    FragColor = vec4(uColor.rgb * intensity, intensity * uColor.a);
}