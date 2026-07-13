shader_type spatial;
render_mode world_vertex_coords;

const float EPSILON = 1e-5;

struct Wave {
	float amplitude;
	float frequency;
	float offset;
	vec2 direction;
};

uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D screen_texture : hint_screen_texture;

uniform vec3 color : source_color = vec3(0.2, 0.3, 0.6);
uniform float normal_strength = 1.0;
uniform float specular = 0.3;
uniform float roughness = 0.3;
uniform float metallic = 0.0;
uniform float wave_strength = 1.0;
uniform float time_scale = 1.0;

// group_uniforms SSR;

// uniform float ssr_resolution   : hint_range(0.01, 10.0, 0.1)	= 1.0;
// uniform float ssr_max_travel   : hint_range(0.0, 200.0, 0.1) 	= 30.0;
// uniform float ssr_max_diff     : hint_range(0.1, 10.0, 0.1) 	= 4.0;
// uniform float ssr_mix_strength : hint_range(0.0, 1.0, 0.01) 	= 0.7;
// uniform float ssr_screen_border_fadeout: hint_range(0.0, 1.0, 0.1)	= 0.3;

const Wave waves[] = {
Wave(0.7f, 0.005f, 0.34607890423724263f, vec2(-0.8926928682552505f, -0.4506655555577927f)),
Wave(0.588f, 0.005600000000000001f, 0.6016964491417672f, vec2(0.5361229026047912f, 0.8441399370380562f)),
Wave(0.49391999999999997f, 0.0062720000000000015f, 0.5506169284954573f, vec2(-0.27499131478577404f, -0.9614467103237658f)),
Wave(0.41489279999999995f, 0.007024640000000002f, 0.09652639411329345f, vec2(0.9495781662470033f, -0.31353039116962583f)),
Wave(0.34850995199999996f, 0.007867596800000003f, 0.14735406146421137f, vec2(0.3168030468805237f, -0.9484913439179172f)),
Wave(0.29274835967999996f, 0.008811708416000005f, 0.5627041645325788f, vec2(-0.19559296449891184f, -0.980685164687693f)),
Wave(0.24590862213119996f, 0.009869113425920006f, 0.3135626234270027f, vec2(0.9463004952121268f, -0.3232883739964732f)),
Wave(0.20656324259020795f, 0.011053407037030408f, 0.25959952480358583f, vec2(-0.9082305883029342f, -0.41847006878736986f)),
Wave(0.17351312377577466f, 0.012379815881474058f, 0.49375824272918156f, vec2(0.9568303979727464f, -0.2906468467321052f)),
Wave(0.1457510239716507f, 0.013865393787250945f, 0.016211501261085393f, vec2(-0.35073205180019146f, -0.9364758554495828f)),
Wave(0.12243086013618659f, 0.01552924104172106f, 0.1304716668845135f, vec2(0.8502433437578579f, 0.5263898331041901f)),
Wave(0.10284192251439674f, 0.01739274996672759f, 0.5330561286678807f, vec2(-0.6579409875313667f, 0.753069490104499f)),
Wave(0.08638721491209325f, 0.0194798799627349f, 0.3394237720541561f, vec2(0.19519910215045885f, 0.9807636364178959f)),
Wave(0.07256526052615833f, 0.02181746555826309f, 0.45183951262854805f, vec2(-0.5729351170328296f, 0.8196007269827046f)),
Wave(0.060954818841973f, 0.024435561425254663f, 0.9611241059977559f, vec2(-0.8789000478425131f, -0.47700598099230174f)),
Wave(0.05120204782725732f, 0.027367828796285226f, 0.5030902730893902f, vec2(0.9981586445570307f, -0.06065740099997097f)),
Wave(0.04300972017489615f, 0.030651968251839457f, 0.7822454905481238f, vec2(-0.9993557812488213f, 0.035889030142345f)),
Wave(0.03612816494691276f, 0.0343302044420602f, 0.12492696250942881f, vec2(0.6036134128514123f, -0.7972771461831014f)),
Wave(0.030347658555406717f, 0.038449828975107424f, 0.5539954899551582f, vec2(-0.4800916219207665f, -0.8772183505613f)),
Wave(0.02549203318654164f, 0.043063808452120315f, 0.26709932164775263f, vec2(0.80532647847346f, 0.5928315638269742f)),
Wave(0.021413307876694977f, 0.04823146546637476f, 0.32112083311272344f, vec2(-0.2934696911992239f, -0.955968378319823f)),
Wave(0.01798717861642378f, 0.054019241322339734f, 0.841624344646415f, vec2(-0.9254249065109856f, 0.3789310523157655f)),
Wave(0.015109230037795974f, 0.06050155028102051f, 0.3327239264071732f, vec2(-0.7751668965686952f, 0.6317565056760854f)),
Wave(0.012691753231748619f, 0.06776173631474297f, 0.1557186286054707f, vec2(-0.14981325824089536f, -0.9887143104331234f)),
Wave(0.010661072714668839f, 0.07589314467251214f, 0.39514492727254f, vec2(0.9943935293813548f, 0.10574265328850299f)),
Wave(0.008955301080321824f, 0.0850003220332136f, 0.826658522178251f, vec2(-0.04908559264234761f, -0.998794575773692f)),
Wave(0.007522452907470332f, 0.09520036067719924f, 0.12363849691788786f, vec2(0.3271670706948451f, 0.9449665114981346f)),
Wave(0.0063188604422750785f, 0.10662440395846316f, 0.019336830379333647f, vec2(0.9885883767235062f, 0.15064203067929913f)),
Wave(0.005307842771511066f, 0.11941933243347876f, 0.6249720739387808f, vec2(0.36476766924220577f, -0.9310985702253058f)),
Wave(0.004458587928069295f, 0.1337496523254962f, 0.531835424919742f, vec2(0.9315105736394628f, 0.36371424387543455f)),
Wave(0.0037452138595782075f, 0.14979961060455577f, 0.9439328711189685f, vec2(0.6588934400185626f, 0.752236289140922f)),
Wave(0.003145979642045694f, 0.16777556387710246f, 0.20300367073966663f, vec2(-0.9894975692234914f, -0.14454950882241627f))
};

// bool is_zero(float value) 
// {
//     return abs(value) < EPSILON;
// }

// bool is_within_screen_boundaries(vec2 position) 
// {
// 	return position.x > 0.0 && position.x < 1.0 && position.y > 0.0 && position.y < 1.0;
// }

// vec2 get_uv_from_view_position(vec3 position_view_space, mat4 proj_m)
// {
// 	vec4 position_clip_space = proj_m * vec4(position_view_space.xyz, 1.0);
// 	vec2 position_ndc = position_clip_space.xy / position_clip_space.w;
// 	return position_ndc.xy * 0.5 + 0.5;
// }

// vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m)
// {
// 	vec4 position_ndc = vec4((uv * 2.0) - 1.0, depth, 1.0);
// 	vec4 view_position = inv_proj_m * position_ndc;
// 	return view_position.xyz /= view_position.w;
// }

// float get_screen_border_alpha(vec2 screen_position)
// {
//     vec2 shifted_screen_position = 4.0 * screen_position * (1.0 - screen_position);
// 	float mask = shifted_screen_position.x * shifted_screen_position.y; // ranging from 0.0 at the edges to 1.0 in the center 

// 	// An offset in the [0.0, 0.5] range for ssr_screen_border_fadeout values > 0.75
// 	// which is subtracted from the result of smoothstep.
// 	// This ensure alpha smoothly transitions to zero when ssr_screen_border_fadeout is approaching 1.0.	
// 	float offset = mix(0.0, 0.5, (clamp(ssr_screen_border_fadeout, 0.75, 1.0)-0.75) / 0.25);
// 	float alpha = clamp(smoothstep(0.0, 2.0 * ssr_screen_border_fadeout, mask) - offset, 0.0, 1.0);

// 	return is_zero(ssr_screen_border_fadeout) ? 1.0 : alpha;
// }

// vec4 get_ssr_color(vec3 surface_view_position, vec3 normal_view_space, vec3 view_view_space, mat4 proj_m, mat4 inv_proj_m)
// {
// 	if (ssr_max_travel < EPSILON)
// 	{
// 		return vec4(0);
// 	}
	
// 	vec3 current_position_view_space = surface_view_position;
// 	vec3 view_direction_view_space = view_view_space * -1.0;
// 	vec3 reflect_vector_view_space = normalize(reflect(view_direction_view_space.xyz, normal_view_space.xyz));
	
// 	vec2 current_screen_position = vec2(0.0);
	
// 	vec3 resulting_color = vec3(-1.0);
// 	for(float travel=0.0; resulting_color.x < 0.0 && travel < ssr_max_travel; travel = travel + ssr_resolution)
// 	{
// 		current_position_view_space += reflect_vector_view_space * ssr_resolution;
// 		current_screen_position = get_uv_from_view_position(current_position_view_space, proj_m);

// 		float depth_texture_probe_raw = texture(depth_texture, current_screen_position).x;
// 		vec3 depth_texture_probe_view_position = get_view_position_from_uv(current_screen_position, depth_texture_probe_raw, inv_proj_m);
		
// 		float depth_diff = depth_texture_probe_view_position.z - current_position_view_space.z;
		
// 		vec3 ssr_screen_color = texture(screen_texture, current_screen_position.xy).rgb;
// 		resulting_color = (is_within_screen_boundaries(current_screen_position) && depth_diff >= 0.0 && depth_diff < ssr_max_diff) ? ssr_screen_color : vec3(-1.0);
// 	}

// 	float alpha = get_screen_border_alpha(current_screen_position);
// 	return vec4(resulting_color,alpha);
// }

void vertex() {
	for (int i = 0; i < waves.length(); i++) {
		Wave wave = waves[i];
		VERTEX.y += wave_strength * wave.amplitude * 0.5 * (0.5 + sin(PI * (time_scale * TIME + wave.offset + wave.frequency * (wave.direction.x * VERTEX.x + wave.direction.y * VERTEX.z))));
	}
	
	ROUGHNESS = roughness;
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	vec2 deriv = vec2(0.0);
	for (int i = 0; i < waves.length(); i++) {
		Wave wave = waves[i];
		deriv += wave_strength * wave.direction * wave.amplitude * PI * wave.frequency * cos(PI * (time_scale * TIME + wave.offset + wave.frequency * (wave.direction.x * world_pos.x + wave.direction.y * world_pos.z)));
	}

	deriv *= normal_strength;
	
	NORMAL_MAP = normalize(vec3(deriv.x, deriv.y, 1.0));
	NORMAL_MAP = NORMAL_MAP * 0.5 + 0.5;

	ROUGHNESS = roughness;
	SPECULAR = specular;
	METALLIC = metallic;
	
	ALBEDO = color;

	float depth = texture(depth_texture, SCREEN_UV).x;

	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	#endif
	
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
	
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	world.xyz /= world.w;

	if (world_pos.y - world.y < 15.0) {
		ALBEDO = mix(vec3(1.0), ALBEDO, clamp(pow((world_pos.y - world.y) / 15.0, 0.2), 0.0, 1.0));
	}

	// vec3 surface_view_position 	= get_view_position_from_uv(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX);

	// vec4 ssr_color 					= get_ssr_color(surface_view_position, NORMAL, VIEW, PROJECTION_MATRIX, INV_PROJECTION_MATRIX);

	// vec3 surface_color_ssr_mix		= (ssr_max_travel > EPSILON) ? mix(ALBEDO, ssr_color.rgb, ssr_mix_strength * ssr_color.a) : vec3(0);
	// vec3 water_color 				= (ssr_color.x >= 0.0) ? surface_color_ssr_mix : ALBEDO;

	// ALBEDO = water_color;
}