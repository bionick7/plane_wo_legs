shader_type spatial;

#include "res://shaderincludes/cloud_shadows.gdshaderinc"
#include "res://shaderincludes/custom_pbr.gdshaderinc"

//#define TRANSPERENCY

uniform sampler2D water_noise;
uniform float uv_strech = 1;

uniform vec2 vel1 = vec2(0);
uniform vec2 vel2 = vec2(0);
uniform float mixing_factor: hint_range(0.0, 1.0) = 0.5;

uniform vec4 color: source_color;
uniform vec4 fresnel_color: source_color;
uniform float roughness: hint_range(0.0, 1.0) = 0.5;

global uniform sampler2D hatching_noise;

varying float custom_shadow;
varying vec2 hatching_uv;

#ifdef TRANSPERENCY
uniform sampler2D screen_texture: hint_screen_texture;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
#endif

void fragment() {	
	vec2 uv1 = UV * vec2(1, uv_strech) * 10. + vel1 * TIME * 1e-3;
	vec2 uv2 = UV * vec2(1, uv_strech) * 10. + vel2 * TIME * 1e-3;
	vec3 wave_normal1 = texture(water_noise, uv1).rgb;
	vec3 wave_normal2 = texture(water_noise, uv2).rgb;
	NORMAL_MAP = mix(wave_normal1, wave_normal2, mixing_factor);
	NORMAL_MAP_DEPTH = 1.0;
	
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	
	vec3 surface_world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	custom_shadow = 1.0;
	custom_shadow = get_light_at_point(surface_world_pos, 0.0);
	
	//light = 1.0;
	
	vec3 surface_color = mix(color.rgb, fresnel_color.rgb, fresnel);
	//surface_color = color.rgb;

#ifdef TRANSPERENCY
	vec3 subsurface_color = texture(screen_texture, SCREEN_UV).rgb;
	
	float depth_tex = texture(pausedepth_texture, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_tex, 1.0);
	vec3 world_pos = (INV_VIEW_MATRIX * upos / upos.w).xyz;
	float water_depth = length(world_pos - surface_world_pos);
	float water_beer = exp(-water_depth * 5e-2);
	ALBEDO = mix(surface_color, subsurface_color, water_beer);
#else
	ALBEDO = surface_color.rgb;
#endif
	//ROUGHNESS = mix(1., roughness, smoothstep(0.4, 0.6, light));
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	hatching_uv = SCREEN_UV * vec2(1., 10.);
}

#ifdef CUSTOM_LIGHTING
void light() {
	float a = texture(hatching_noise, hatching_uv).r * 2. - 1.;
	
	float attenuation = ATTENUATION * mix(0.1, 1.0, custom_shadow);
	//attenuation = ATTENUATION;
	DIFFUSE_LIGHT += get_diffuse_lighting(NORMAL, LIGHT, ALBEDO) * LIGHT_COLOR * attenuation;
	float specular_threshhold = .6 + a * .5;
	SPECULAR_LIGHT += step(specular_threshhold, .2 * get_specular_simple(NORMAL, LIGHT, VIEW, ROUGHNESS*ROUGHNESS)) * LIGHT_COLOR * .1 * attenuation;
	//DIFFUSE_LIGHT = vec3(step(.95, dot(NORMAL, LIGHT)));
	//SPECULAR_LIGHT = vec3(step(.15, dot(NORMAL, LIGHT))) * .15;
}
#endif
