shader_type spatial;
render_mode diffuse_lambert;
render_mode specular_schlick_ggx;

uniform float roughness : hint_range(0, 1) = 0.2;
uniform vec4 color : source_color = vec4(0, 0, 1, 1);
uniform float highlight_threshhold : hint_range(0, 1) = 0.3;
uniform float filllight_threshhold : hint_range(0, 1) = 0.8;
uniform float rimlight_threshhold : hint_range(0, 1) = 0.15;

void fragment() {
	ALBEDO = color.rgb;
	ROUGHNESS = roughness;
	float rim = step(dot(NORMAL, VIEW), rimlight_threshhold);
	vec3 rim_color = mix(NORMAL, vec3(1), 0.6);
	ALBEDO = vec3(mix(color.rgb, rim_color, rim));
}

void light() {
	DIFFUSE_LIGHT += vec3(step(highlight_threshhold, dot(NORMAL, LIGHT))) * ATTENUATION;
	SPECULAR_LIGHT += vec3(step(filllight_threshhold, dot(NORMAL, LIGHT))) * .15 * step(0.5, ATTENUATION);
}