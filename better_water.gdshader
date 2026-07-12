shader_type spatial;
render_mode world_vertex_coords;

struct Wave {
	float amplitude;
	float wave_length;
	vec2 direction;
};

//const Wave wave = Wave(0.1f, 1.0f, vec2(0.7f, 0.7f));

const Wave waves[] = { 
	Wave(0.1f, 1.0f, vec2(0.7f, 0.7f)),
	Wave(0.05f, 0.5f, vec2(1.0f, 0.0f)),
	Wave(0.05f, 0.5f, vec2(0.0f, 1.0f))
};

void vertex() {
	for (int i = 0; i < waves.length(); i++) {
		Wave wave = waves[i];
		VERTEX.y += wave.amplitude * sin(PI * (TIME + (wave.direction.x * VERTEX.x + wave.direction.y * VERTEX.z) / wave.wave_length));
	}
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0f)).xyz;
	
	vec2 deriv = vec2(0.0f);
	for (int i = 0; i < waves.length(); i++) {
		Wave wave = waves[i];
		deriv += wave.direction * wave.amplitude * PI * cos(PI * (TIME + (wave.direction.x * world_pos.x + wave.direction.y * world_pos.z) / wave.wave_length));
	}
	
	deriv /= float(waves.length());
	
	NORMAL_MAP = cross(vec3(1.0f, 0.0f, deriv.x), vec3(0.0f, 1.0f, deriv.y)) * 0.5f + 0.5f;
	
	ALBEDO = vec3(0.3f, 0.3f, 0.6f);
}