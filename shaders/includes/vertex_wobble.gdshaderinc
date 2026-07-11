#ifndef VERTEX_WOBBLE_INCLUDED
#define VERTEX_WOBBLE_INCLUDED

float vertex_wobble(
    vec3 position,
    float time,
    float strength,
    float speed,
    float frequency
) {
    return sin(
        time * speed +
        (position.x + position.z) * frequency
    ) * strength;
}


float vertex_wobble_noise(
    vec3 position,
    float time,
    float strength,
    float speed,
    float frequency
) {
    float wave_x = sin(
        position.x * frequency +
        time * speed
    );

    float wave_z = cos(
        position.z * frequency * 1.3 +
        time * speed * 0.8
    );

    return (wave_x + wave_z) * 0.5 * strength;
}

#endif