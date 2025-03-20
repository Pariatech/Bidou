#version 410

layout(location = 0) in vec2 pos;
layout(location = 1) in vec4 color;

layout(location = 0) out vec4 frag_color;

void main() {
    gl_Position = vec4(pos, -1.0, 1.0);
    frag_color = color;
}
