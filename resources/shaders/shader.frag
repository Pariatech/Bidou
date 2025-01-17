#version 410

uniform sampler2DArray texture_sampler;
uniform sampler2DArray mask_sampler;

uniform UniformBufferObject {
    mat4 proj;
    mat4 view;
} ubo;

layout(location = 0) in vec3 frag_light;
layout(location = 1) in vec4 frag_texcoord;

layout(location = 0) out vec4 color;

void main() {
    vec4 tex = texture(texture_sampler, frag_texcoord.rgb);
    vec4 mask_tex; 
    if (frag_texcoord.r < -0.01 || frag_texcoord.r > 1.01) {
        mask_tex = vec4(1);
    } else {
        mask_tex = texture(mask_sampler, frag_texcoord.rga);
    }
    if (tex.a * mask_tex.a < 0.01) {
        discard;
    }
    color = vec4(frag_light * tex.rgb * mask_tex.rgb, tex.a * mask_tex.a);
    // color = vec4(frag_light * tex.rgb, tex.a);
}
