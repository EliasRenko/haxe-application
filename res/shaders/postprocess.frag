#version 330 core
in vec2 TexCoord;
out vec4 FragColor;
uniform sampler2D uScreenTexture;

void main() {
    vec4 color = texture(uScreenTexture, TexCoord);
    vec3 inverted = 1.0 - color.rgb;
    vec3 tinted = mix(inverted, vec3(0.15, 0.35, 0.95), 0.25);
    FragColor = vec4(tinted, color.a);
}
