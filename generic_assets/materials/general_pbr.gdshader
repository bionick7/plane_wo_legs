shader_type spatial;

#include "res://shaderincludes/cloud_shadows.gdshaderinc"
#include "res://shaderincludes/custom_pbr.gdshaderinc"

uniform vec4 albedo: source_color;
uniform float roughness: hint_range(0.0, 1.0) = 0.5;
uniform float metallicity: hint_range(0.0, 1.0) = 0.0;

uniform sampler2D normal_map: hint_default_white;
uniform sampler2D albedo_map: hint_default_white;

varying float custom_shadow;


void fragment() {
	vec3 surface_world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	custom_shadow = get_light_at_point(surface_world_pos, 0.0);
	//custom_shadow = 1.0;
	
	//NORMAL_MAP = texture(normal_map, UV).rgb;
	ALBEDO = texture(albedo_map, UV).rgb * albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallicity;
}


#ifdef CUSTOM_LIGHTING

void light() {
	float attenuation = ATTENUATION * mix(0.1, 1.0, custom_shadow);
	//attenuation = ATTENUATION;
	DIFFUSE_LIGHT += get_diffuse_lighting(NORMAL, LIGHT, ALBEDO) * LIGHT_COLOR * attenuation;
	SPECULAR_LIGHT += get_specular_lighting(NORMAL, LIGHT, VIEW, ROUGHNESS*ROUGHNESS) * 0.1 * LIGHT_COLOR * attenuation;
}
#endif
