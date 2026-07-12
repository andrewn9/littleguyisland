shader_type spatial;
render_mode world_vertex_coords;

struct Wave {
	float amplitude;
	float frequency;
	float speed;
	vec2 direction;
};

const Wave waves[] = {
Wave(10.0f, 0.001f, 0.8f, vec2(-0.5349026052653505f, -0.8449137251106416f)),
Wave(6.0f, 0.002f, 1.2f, vec2(0.8306604310525707f, -0.5567793533201078f)),
Wave(3.5999999999999996f, 0.004f, 1.5199999999999998f, vec2(-0.2851173753072728f, 0.9584926094122436f)),
Wave(2.1599999999999997f, 0.008f, 1.7759999999999998f, vec2(0.7261900086202961f, 0.6874940518870357f)),
Wave(1.2959999999999998f, 0.016f, 1.9808f, vec2(0.2725909366347826f, -0.9621300230553934f)),
Wave(0.7775999999999998f, 0.032f, 2.14464f, vec2(-0.6946757092617939f, -0.7193230560475756f))
};

void vertex() {
	for (int i = 0; i < waves.length(); i++) {
		Wave wave = waves[i];
		VERTEX.y += wave.amplitude * 0.5f * (0.5f + sin(PI * (TIME + wave.frequency * (wave.direction.x * VERTEX.x + wave.direction.y * VERTEX.z))));
	}
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0f)).xyz;
	
	vec2 deriv = vec2(0.0f);
	for (int i = 0; i < waves.length(); i++) {
		Wave wave = waves[i];
		deriv += wave.direction * wave.amplitude * PI * wave.frequency * cos(PI * (TIME + wave.frequency * (wave.direction.x * world_pos.x + wave.direction.y * world_pos.z)));
	}
	
	deriv /= float(waves.length());
	
	//NORMAL_MAP = normalize(cross(normalize(vec3(1.0f, 0.0f, deriv.x)), normalize(vec3(0.0f, 1.0f, deriv.y))));
	NORMAL_MAP = normalize(vec3(deriv.x, deriv.y, 1.0f));
	NORMAL_MAP = NORMAL_MAP * 0.5f + 0.5f;
	
	ROUGHNESS = 0.3;
	SPECULAR = 0.3;
	
	ALBEDO = vec3(0.3f, 0.3f, 0.6f);
}