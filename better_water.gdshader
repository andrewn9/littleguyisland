shader_type spatial;
render_mode world_vertex_coords;

struct Wave {
	float amplitude;
	float wave_length;
	vec2 direction;
};

//const Wave wave = Wave(0.1f, 1.0f, vec2(0.7f, 0.7f));

const Wave waves[] = { Wave(5.0f, 100.0f, vec2(0.71f, 0.71f)) };

void vertex() {
	for (int i = 0; i < waves.length(); i++) {
		Wave wave = waves[i];
		VERTEX.y += wave.amplitude * 0.5f * (0.5f + sin(PI * (TIME + (wave.direction.x * VERTEX.x + wave.direction.y * VERTEX.z) / wave.wave_length)));
	}
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0f)).xyz;
	
	vec2 deriv = vec2(0.0f);
	for (int i = 0; i < waves.length(); i++) {
		Wave wave = waves[i];
		deriv += wave.direction * wave.amplitude * PI / wave.wave_length * cos(PI * (TIME + (wave.direction.x * world_pos.x + wave.direction.y * world_pos.z) / wave.wave_length));
	}
	
	deriv /= float(waves.length());
	
	//NORMAL_MAP = normalize(cross(normalize(vec3(1.0f, 0.0f, deriv.x)), normalize(vec3(0.0f, 1.0f, deriv.y))));
	NORMAL_MAP = normalize(vec3(deriv.x, deriv.y, 1.0f));
	NORMAL_MAP = NORMAL_MAP * 0.5f + 0.5f;
	
	ROUGHNESS = 0.3;
	SPECULAR = 0.3;
	
	ALBEDO = vec3(0.3f, 0.3f, 0.6f);
}