#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;
uniform vec4 uColor = vec4(1.0, 1.0, 1.0, 1.0);

void main() {
    vec4 texSample = texture(uTexture, TexCoord);

    // GL_RED (grayscale): vec4(r, 0, 0, 1) — glyph in .r, .a == 1.0
    // GL_RGBA (white+alpha): vec4(1, 1, 1, a) — glyph in .a, .r == 1.0
    float mask = texSample.r * texSample.a;

    FragColor = vec4(uColor.rgb, uColor.a * mask);
}