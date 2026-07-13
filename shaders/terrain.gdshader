shader_type spatial;

//#include "includes/vertex_wobble.gdshaderinc"

uniform sampler2D heightmap : source_color;
uniform sampler2D valuemap : source_color;

uniform float height_scale = 20.0;
uniform vec2 uv_scale = vec2(8.0);
uniform float texel_size;
uniform float near_threshold = 0.5;

uniform sampler2D land_ramp : source_color, repeat_disable;
uniform sampler2D mountain_ramp : source_color, repeat_disable;
uniform sampler2D base_ramp : source_color, repeat_disable;

uniform vec3 land_key : source_color = vec3(0.357, 0.635, 0.122);
uniform vec3 mountain_key : source_color = vec3(0.745, 0.745, 0.745);
uniform vec3 water_key : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 base_key : source_color = vec3(0.98, 0.92, 0.835);

uniform float region_sharpness : hint_range(1.0, 12.0) = 6.0;


// Wobble controls
uniform float wobble_strength = 0.2;
uniform float wobble_speed = 1.0;
uniform float wobble_frequency = 3.0;


float height(vec2 uv){
    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    return texture(heightmap, uv).r * height_scale;
	#else
    return pow(texture(heightmap, uv).r, 1.0 / 2.2) * height_scale;
    // return texture(heightmap, uv).r * height_scale;
	#endif
}


void vertex() {
    float h = height(UV);

    float hl = height(UV + vec2(-texel_size,0));
    float hr = height(UV + vec2(texel_size,0));
    float hd = height(UV + vec2(0,-texel_size));
    float hu = height(UV + vec2(0,texel_size));


    VERTEX.y = h;


    //// Apply wobble
    //VERTEX.y += vertex_wobble_noise(
        //VERTEX,
        //TIME,
        //wobble_strength,
        //wobble_speed,
        //wobble_frequency
    //);


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
	// circular map: everything outside the inscribed circle doesn't exist
	if (distance(UV, vec2(0.5)) > 0.5) {
		discard;
	}
	if (height(UV) < near_threshold) {
	    bool nearKept =
	        height(UV + vec2(-texel_size, 0.0)) >= near_threshold ||
	        height(UV + vec2( texel_size, 0.0)) >= near_threshold ||
	        height(UV + vec2(0.0, -texel_size)) >= near_threshold ||
	        height(UV + vec2(0.0,  texel_size)) >= near_threshold;
		if (!nearKept)
			discard;
	}
    vec3 v = texture(valuemap, UV * uv_scale).rgb;
    float e = texture(heightmap, UV).r;

    // pick closest region
    float wl = 1.0 / pow(distance(v, land_key) + 0.02, region_sharpness);
    float wm = 1.0 / pow(distance(v, mountain_key) + 0.02, region_sharpness);
    float wb = 1.0 / pow(distance(v, base_key) + 0.02, region_sharpness);

    ALBEDO = (
        texture(land_ramp, vec2(e, 0.5)).rgb * wl +
        texture(mountain_ramp, vec2(e, 0.5)).rgb * wm +
        texture(base_ramp, vec2(e, 0.5)).rgb * wb
    ) / (wl + wm + wb);

    ROUGHNESS = 0.95;
}