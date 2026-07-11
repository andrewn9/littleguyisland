shader_type spatial;
render_mode unshaded;

uniform sampler2D heightmap : source_color;
uniform sampler2D valuemap : source_color;

uniform float height_scale = 20.0;
uniform vec2 uv_scale = vec2(8.0);
uniform float texel_size;

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

    vec3 tangent = vec3(2.0 * texel_size, hr - hl, 0.0);
    vec3 bitangent = vec3(0.0, hu - hd, 2.0 * texel_size);

    NORMAL = normalize(cross(bitangent, tangent));
}

void fragment() {
    ALBEDO = texture(valuemap, UV * uv_scale).rgb;
    ROUGHNESS = 0.95;
}