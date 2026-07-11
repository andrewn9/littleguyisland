#ifndef NOISE_SQUIGGLE_INCLUDED
#define NOISE_SQUIGGLE_INCLUDED

vec2 get_squiggle_direction(
    sampler2D noise_texture,
    vec2 uv,
    float time,
    float fps
) {
    vec2 noise_offset = floor(time * fps) * vec2(PI, E);

    float noise_sample = texture(
        noise_texture,
        uv + noise_offset
    ).r * 4.0 * PI;

    return vec2(
        cos(noise_sample),
        sin(noise_sample)
    );
}

#endif