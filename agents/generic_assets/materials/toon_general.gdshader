shader_type spatial;
render_mode diffuse_lambert;

#include "res://shaderincludes/custom_pbr.gdshaderinc"

uniform float roughness : hint_range(0, 1) = 0.4;
uniform vec4 color : source_color = vec4(0, 0, 1, 1);
uniform vec4 rimlight_color : source_color = vec4(1);
uniform float highlight_threshhold : hint_range(0, 1) = 0.3;
uniform float highlight_variance : hint_range(0, 1) = 0.4;
uniform float filllight_threshhold : hint_range(0, 1) = 0.3;
uniform float filllight_variance : hint_range(0, 1) = 0.05;
uniform float rimlight_threshhold : hint_range(0, 1) = 0.15;

global uniform sampler2D hatching_noise;

varying vec2 hatching_uv;

void fragment() {
	ALBEDO = color.rgb;
	ROUGHNESS = roughness;
	float rim = step(dot(NORMAL, VIEW), rimlight_threshhold);
	ALBEDO = vec3(mix(color.rgb, rimlight_color.rgb, rim));
	hatching_uv = SCREEN_UV * vec2(1., 10.) * 2.;
}

void light() {
	float a = texture(hatching_noise, hatching_uv).r * 2. - 1.;
	float highlight_threshhold_rand = highlight_threshhold + a*highlight_variance;
	float filllight_threshhold_rand = filllight_threshhold * (1. + a*filllight_variance);
	float diffuse = clamp(dot(NORMAL, LIGHT), 0., 1.);
	DIFFUSE_LIGHT += vec3(0.1) * ATTENUATION;
	//DIFFUSE_LIGHT += vec3(step(filllight_threshhold_rand, diffuse)) * ATTENUATION;
	float spec = get_specular_simple(NORMAL, LIGHT, VIEW, ROUGHNESS*ROUGHNESS);
	SPECULAR_LIGHT += vec3(1.) * step(highlight_threshhold_rand, spec) * ATTENUATION * .15;
	
}