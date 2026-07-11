shader_type spatial;
render_mode vertex_lighting;

#include "includes/vertex_wobble.gdshaderinc"

uniform sampler2D heightmap : source_color;
uniform sampler2D valuemap : source_color;

uniform float height_scale = 20.0;
uniform vec2 uv_scale = vec2(8.0);
uniform float texel_size;
uniform float near_threshold = 0.5;


// Wobble controls
uniform float wobble_strength = 0.2;
uniform float wobble_speed = 1.0;
uniform float wobble_frequency = 3.0;


float height(vec2 uv){
    return texture(heightmap, uv).r * height_scale;
}


void vertex() {
    float h = height(UV);

    float hl = height(UV + vec2(-texel_size,0));
    float hr = height(UV + vec2(texel_size,0));
    float hd = height(UV + vec2(0,-texel_size));
    float hu = height(UV + vec2(0,texel_size));


    VERTEX.y = h;


    // Apply wobble
    VERTEX.y += vertex_wobble_noise(
        VERTEX,
        TIME,
        wobble_strength,
        wobble_speed,
        wobble_frequency
    );


    vec3 tangent = vec3(
        2.0 * texel_size,
        hr - hl,
        0.0
    );

    vec3 bitangent = vec3(
        0.0,
        hu - hd,
        2.0 * texel_size
    );

    NORMAL = normalize(
        cross(bitangent, tangent)
    );
}


void fragment() {
	if (height(UV) < near_threshold) {
	    bool nearKept =
	        height(UV + vec2(-texel_size, 0.0)) >= near_threshold ||
	        height(UV + vec2( texel_size, 0.0)) >= near_threshold ||
	        height(UV + vec2(0.0, -texel_size)) >= near_threshold ||
	        height(UV + vec2(0.0,  texel_size)) >= near_threshold;
		if (!nearKept)
			discard;
	}
    ALBEDO = texture(
        valuemap,
        UV * uv_scale
    ).rgb;

    ROUGHNESS = 0.95;
}