#version 330 core

in vec2 TexCoord;
in float TexIndex;

out vec4 FragColor;

uniform sampler2D uGraphics;
uniform sampler2D uFont;

void main() {
    vec4 color;

    if (TexIndex < 0.5) {
        // Sprite atlas (texture unit 0)
        color = texture(uGraphics, TexCoord);
    } else {
        // Font atlas (texture unit 1) — same alpha-mask decode as text.frag
        vec4 s = texture(uFont, TexCoord);
        float mask = s.r * s.a;
        color = vec4(1.0, 1.0, 1.0, mask);
    }

    if (color.a < 0.01) discard;

    FragColor = color;
}
