#version 410

layout(location = 0) in vec2 pos;
layout(location = 1) in vec2 texcoord;
layout(location = 2) in vec4 color;
layout(location = 3) in vec2 clip_start;
layout(location = 4) in vec2 clip_end;

layout(location = 0) out vec2 frag_texcoord;
layout(location = 1) out vec4 frag_color;
layout(location = 2) out vec2 frag_clip_start;
layout(location = 3) out vec2 frag_clip_end;

void main() {
    gl_Position = vec4(pos, -1.0, 1.0);
    frag_texcoord = texcoord;
    frag_color = color;
    frag_clip_start = clip_start;
    frag_clip_end = clip_end;
}
