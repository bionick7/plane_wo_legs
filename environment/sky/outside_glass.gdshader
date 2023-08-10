shader_type spatial;

#include "res://shaderincludes/cloud_shadows.gdshaderinc"
#include "res://shaderincludes/custom_pbr.gdshaderinc"

uniform sampler2D panorama_sky;
uniform vec4 fresnel_color: source_color;
uniform vec4 metal_color: source_color;
uniform float grid_thickness: hint_range(0.0, 1.0, 0.01) = 0.03;
uniform float roughness: hint_range(0.0, 1.0, 0.01) = 0.3;
uniform float metal_roughness: hint_range(0.0, 1.0, 0.01) = 0.3;

varying float custom_shadow;

void fragment() {
	vec3 global_view = (INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;
	
	vec3 surface_world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	custom_shadow = get_light_at_point(surface_world_pos, 0.0);
	
	float longitude = fract(angle(global_view.xz) / TAU + 0.5);
	float latitude = 1.0 - acos(global_view.y) / PI;
	vec2 spherical_uv = vec2(longitude, latitude);
	
	vec3 outside = texture(panorama_sky, spherical_uv).rgb * 0.1;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	vec2 grid_uv = fract(UV * 100.0);
	float grid_mask = step(1.0 - grid_thickness, grid_uv.x) + step(1.0 - grid_thickness, grid_uv.y);
	
	/*float sun = smoothstep(0.99, 1., dot(-sun_dir, global_view));
	sun *= sun;
	sun *= sun;
	sun *= sun;*/
	
	ALBEDO = mix(
		mix(outside, fresnel_color.rgb, fresnel),
		metal_color.rgb, grid_mask
	);
	METALLIC = grid_mask;
	ROUGHNESS = mix(roughness, metal_roughness, grid_mask);
	//EMISSION = vec3(100.) * sun;
}

#undef CUSTOM_LIGHTING
#ifdef CUSTOM_LIGHTING
void light() {
	float attenuation = ATTENUATION * mix(0.1, 1.0, custom_shadow);
	DIFFUSE_LIGHT += get_diffuse_lighting(NORMAL, LIGHT, ALBEDO) * LIGHT_COLOR * attenuation;
	//SPECULAR_LIGHT += step(.9, .6 * get_specular_lighting(NORMAL, LIGHT, VIEW, ROUGHNESS*ROUGHNESS)) * LIGHT_COLOR * .1 * attenuation;
	SPECULAR_LIGHT += get_specular_lighting(NORMAL, LIGHT, VIEW, ROUGHNESS*ROUGHNESS) * 0.3 * LIGHT_COLOR * attenuation;
}
#endif // CUSTOM_LIGHTING
#define CUSTOM_LIGHT