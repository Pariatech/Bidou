#version 410

uniform sampler2DArray texture_sampler;
uniform sampler2DArray depth_map_texture_sampler;

layout(location = 0) in vec3  frag_light;
layout(location = 1) in vec2  frag_texcoord;
layout(location = 2) in float frag_texture_index;
layout(location = 3) in float frag_depth_map;

layout(location = 0) out vec4 frag_color;

void main() {
    vec2 texelSize = vec2(1/512, 1/1024);
    // SSAA 3x3 grid sampling positions
    vec2 offsets[9] = vec2[](
        vec2(-1.0,  1.0), // Top-left
        vec2( 0.0,  1.0), // Top-center
        vec2( 1.0,  1.0), // Top-right
        vec2(-1.0,  0.0), // Middle-left
        vec2( 0.0,  0.0), // Middle-center
        vec2( 1.0,  0.0), // Middle-right
        vec2(-1.0, -1.0), // Bottom-left
        vec2( 0.0, -1.0), // Bottom-center
        vec2( 1.0, -1.0)  // Bottom-right
    );
    
    vec4 color = vec4(0.0);
    
    // Accumulate the color from 9 samples
    for(int i = 0; i < 9; i++)
    {
        vec2 sample_pos = frag_texcoord + offsets[i] * texelSize;
        color += texture(texture_sampler, vec3(sample_pos, frag_texture_index));
    }

    // Average the samples
    color /= 9.0;
    color = vec4(frag_light * color.rgb, color.a);

    // vec4 tex = texture(texture_sampler, vec3(frag_texcoord, frag_texture_index));
    // vec4 color = vec4(frag_light * tex.rgb, tex.a);
    if (color.a < 0.01) {
        discard;
    }
    frag_color = color;

    float depth = gl_FragCoord.z;

    float depth_from_map = 0;
    int depth_samples = 0;
    for(int i = 0; i < 9; i++)
    {
        vec2 sample_pos = frag_texcoord + offsets[i] * texelSize;
        float depth_sample = texture(depth_map_texture_sampler, vec3(sample_pos, frag_depth_map)).r;
        if (depth_sample < 1) {
            depth_samples += 1;
            depth_from_map += depth_sample;
            // depth_from_map = depth_sample;
        } 
    }
    if (depth_samples > 0) {
        depth_from_map /= depth_samples;
    }

    // float depth_from_map = texture(depth_map_texture_sampler, vec3(frag_texcoord, frag_depth_map)).r;
    depth += depth_from_map;

    gl_FragDepth = depth;
}
