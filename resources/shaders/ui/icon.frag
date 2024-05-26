#version 450


layout(binding = 0) uniform UniformBufferObject {
	vec4  border_inner_color;
	vec4  border_outer_color;
	float border_width;
} ubo;

uniform sampler2DArray texture_sampler;

layout(location = 0) in vec2  start;
layout(location = 1) in vec2  end;
layout(location = 2) in vec4  color;
layout(location = 3) in vec3  texcoord;

layout(location = 0) out vec4 frag_color;

layout(origin_upper_left) in vec4 gl_FragCoord;

void main() {
    vec4 coord = gl_FragCoord;

    // discard corners
    if (coord.x < start.x + ubo.border_width &&
        coord.y < start.y + ubo.border_width) {
        discard;
        return;
    }
    
    if (coord.x > end.x - ubo.border_width &&
        coord.y < start.y + ubo.border_width) {
        discard;
        return;
    }
    
    if (coord.x > end.x - ubo.border_width &&
        coord.y > end.y - ubo.border_width) {
        discard;
        return;
    }
    
    if (coord.x < start.x + ubo.border_width &&
        coord.y > end.y - ubo.border_width) {
        discard;
        return;
    }

    // outer border
    if (coord.x < start.x + ubo.border_width) {
        frag_color = ubo.border_outer_color;
        return;
    }

    if (coord.x > end.x - ubo.border_width) {
        frag_color = ubo.border_outer_color;
        return;
    }

    if (coord.y < start.y + ubo.border_width) {
        frag_color = ubo.border_outer_color;
        return;
    }

    if (coord.y > end.y - ubo.border_width) {
        frag_color = ubo.border_outer_color;
        return;
    }

    if (coord.x < start.x + ubo.border_width * 2 &&
        coord.y < start.y + ubo.border_width * 2) {
        frag_color = ubo.border_outer_color;
        return;
    }
    
    if (coord.x > end.x - ubo.border_width * 2 &&
        coord.y < start.y + ubo.border_width * 2) {
        frag_color = ubo.border_outer_color;
        return;
    }
    
    if (coord.x > end.x - ubo.border_width * 2 &&
        coord.y > end.y - ubo.border_width * 2) {
        frag_color = ubo.border_outer_color;
        return;
    }
    
    if (coord.x < start.x + ubo.border_width * 2 &&
        coord.y > end.y - ubo.border_width * 2) {
        frag_color = ubo.border_outer_color;
        return;
    }

    // inner border 
    if (coord.x < start.x + ubo.border_width * 2) {
        frag_color = ubo.border_inner_color;
        return;
    }

    if (coord.x > end.x - ubo.border_width * 2) {
        frag_color = ubo.border_inner_color;
        return;
    }

    if (coord.y < start.y + ubo.border_width * 2) {
        frag_color = ubo.border_inner_color;
        return;
    }

    if (coord.y > end.y - ubo.border_width * 2) {
        frag_color = ubo.border_inner_color;
        return;
    }

    if (coord.x < start.x + ubo.border_width * 3 &&
        coord.y < start.y + ubo.border_width * 3) {
        frag_color = ubo.border_inner_color;
        return;
    }
    
    if (coord.x > end.x - ubo.border_width * 3 &&
        coord.y < start.y + ubo.border_width * 3) {
        frag_color = ubo.border_inner_color;
        return;
    }
    
    if (coord.x > end.x - ubo.border_width * 3 &&
        coord.y > end.y - ubo.border_width * 3) {
        frag_color = ubo.border_inner_color;
        return;
    }
    
    if (coord.x < start.x + ubo.border_width * 3 &&
        coord.y > end.y - ubo.border_width * 3) {
        frag_color = ubo.border_inner_color;
        return;
    }

    vec4 tex = texture(texture_sampler, texcoord);
    frag_color = mix(color, vec4(tex.rgb, 1), tex.a);
}