#version 410

uniform sampler2D texture_sampler;

layout(location = 0) in vec2 frag_texcoord;
layout(location = 1) in vec4 frag_color;

layout(location = 0) out vec4 color;

void main() {
    float alpha = texture(texture_sampler, frag_texcoord).r;
    color = vec4(frag_color.rgb, frag_color.a * alpha);
}
