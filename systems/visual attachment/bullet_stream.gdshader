shader_type spatial;
render_mode unshaded, cull_disabled;
render_mode skip_vertex_transform;

uniform float time;
uniform int max_index;
uniform vec4 color: source_color = vec4(1, 1, 1, 1);
uniform float fade_time_start = 2.0;

varying smooth float end_time;

void vertex() {
	vec3 pos0 = VERTEX;
	vec3 vel = CUSTOM0.xyz;
	end_time = CUSTOM0.w;
	// global coordinates (skip model matrix)
	VERTEX = (VIEW_MATRIX * vec4(pos0 + vel * time, 1)).xyz;
	if (VERTEX_ID == max_index-1 || VERTEX_ID == max_index) {
		end_time = -1e6;
	}
}

void fragment() {
	float to_live = end_time - time;
	if (to_live < 0.0) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = smoothstep(0.0, fade_time_start, to_live) * color.a;
}
