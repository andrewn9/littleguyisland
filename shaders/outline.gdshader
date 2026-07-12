shader_type canvas_item;
render_mode world_vertex_coords;

#include "includes/noise_squiggle.gdshaderinc"

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;


group_uniforms Lines;

uniform float weight = 0.07;
uniform float line_thickness : hint_range(0.0, 6.0) = 1.0;
uniform vec3 color : source_color;
uniform float opacity : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D background_texture : hint_default_transparent;


group_uniforms Squiggle;

uniform vec2 scale = vec2(10.0, 10.0);
uniform float strength = 0.5;
uniform float fps = 6.0;

uniform sampler2D noise : filter_linear, repeat_enable;


varying vec4 modulate;
varying vec2 noise_uv;


void vertex() {
    modulate = COLOR;

    noise_uv = (
        VERTEX - MODEL_MATRIX[3].xy
    ) / (
        vec2(textureSize(noise, 0)) * scale
    );
}


void fragment() {

    vec2 direction = get_squiggle_direction(
        noise,
        noise_uv,
        TIME,
        fps
    );


    vec2 squiggle_uv =
        SCREEN_UV +
        direction * strength * 0.005;


    vec3 current_color =
        texture(
            SCREEN_TEXTURE,
            squiggle_uv
        ).rgb;


    vec3 right_color =
        texture(
            SCREEN_TEXTURE,
            squiggle_uv +
            vec2(
                SCREEN_PIXEL_SIZE.x * line_thickness,
                0
            )
        ).rgb;


    vec3 bottom_color =
        texture(
            SCREEN_TEXTURE,
            squiggle_uv -
            vec2(
                0,
                SCREEN_PIXEL_SIZE.y * line_thickness
            )
        ).rgb;


    float r_distance =
        length(current_color - right_color);

    float b_distance =
        length(current_color - bottom_color);


    vec4 background_color =
        texture(
            background_texture,
            UV
        );


    vec4 solid_line =
        vec4(
            color.rgb,
            1.0
        );


    vec4 line_texture =
        (
            r_distance > weight ||
            b_distance > weight
        )
        ? mix(
            background_color,
            solid_line,
            opacity
        )
        : background_color;


    COLOR = line_texture;
}