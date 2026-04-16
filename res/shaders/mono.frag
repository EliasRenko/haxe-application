#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D uTexture;
uniform vec4 uColor = vec4(1.0, 1.0, 1.0, 1.0);

void main() {
    vec4 texSample = texture(uTexture, TexCoord);

    // Support two common bitmap-font texture layouts:
    //   GL_RED  (grayscale): texSample = vec4(r, 0, 0, 1) -- glyph data in .r, .a == 1.0
    //   GL_RGBA (white+alpha): texSample = vec4(1, 1, 1, a) -- glyph data in .a, .r == 1.0
    // Multiplying .r * .a covers both: GL_RED -> r*1 = r, RGBA -> 1*a = a
    float mask = texSample.r * texSample.a;

    FragColor = vec4(uColor.rgb, uColor.a * mask);
}