shader_type spatial;
render_mode unshaded, skip_vertex_transform, cull_disabled;

#include "res://shaderincludes/random.gdshaderinc"
#include "res://shaderincludes/cloud_shadows.gdshaderinc"

uniform float threshhold: hint_range(0, 1) = 0.5;
uniform float cloud_flatten = 4.0;
uniform vec4 noise_weights = vec4(0, 0, 0, 0);
uniform vec4 noise_weights_detail = vec4(0, 0, 0, 0);

uniform vec4 sun_color: source_color = vec4(1.0);
uniform vec4 sky_color: source_color = vec4(0.36, 0.56, 0.6, 1.0);

uniform sampler3D noise: filter_linear, repeat_enable;
uniform sampler2D screen_texture: hint_screen_texture;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

#define MAX_DIST 14e3
#define NORMAL_EPSILON 1.0

float density_map(vec3 p, int lod) {
	float cov = get_coverage(p.xz);
	float rad = dot(p.xy, p.xy);
	float mask = clamp(1.0 - 4e6*p.y*p.y/(layer_thickness*layer_thickness), 0.0, 1.0);
	mask = mask*mask;
	p.y *= cloud_flatten;
	p += vec3(cloud_cover_speed, 0, 0) * cloud_anim_time;
	float n = 0.0;
	n += smoothstep(0.4, 1.2, 
		dot(texture(noise, p / TAU), noise_weights)
		+ dot(texture(noise, p / TAU * 10.0), noise_weights_detail)
	);
	return cov * mask * n;
}

float cartesian_density_map(vec3 p, int lod) {
	return density_map(global_to_cylindrical(p), 3);
}

vec3 scatter(vec3 ro, vec3 rd, float t0, float t1) {
	float dist = t1 - t0;
		
	int r_seed = int(dot(rd, vec3(12.34e3, 56.778e2, 957.5e1)));
	r_seed += rand_int(int(rd.x * 2000.));
	
	float t_l = -1.;
	float t_r = t0 + rand_float(r_seed) * 20.0;
	float f_l;
	float f_r = cartesian_density_map(ro + rd * t_r, 3) - threshhold;
	if (f_r > 0.0) {
		return ro + rd * t0;
	}
	
	for(int i=0; i < 200 && t_r < t1; i++) {
		float dt = clamp(t_r * 0.1, 10.0, 50.0);
		t_r += dt;
		
		f_l = f_r;
		f_r = cartesian_density_map(ro + rd * t_r, 3) - threshhold;
				
		if (f_l*f_r <= 0.0) {
			t_l = t_r - dt;
			break;
		}
	}
	
	if (t_l < 0.0) {
		return vec3(1e6);
	}
	
	return ro + rd * t_l;
}


vec4 main(vec3 screen_color, vec3 camera_pos, vec3 camera_dir, float camera_distance) {
	vec3 c = screen_color;
	
	vec2 trace_result = raytrace_inf_cylinder(camera_pos, camera_dir, 4e3);
	float t_solid = camera_distance;
	if (trace_result.x > 0.0) {
		t_solid = min(t_solid, trace_result.x);
	} if (trace_result.y > 0.0) {
		t_solid = min(t_solid, trace_result.y);
	} else {
		t_solid = 0.0;
	}
	
	vec4 tt = find_cloud_layer_limits(camera_pos, camera_dir, t_solid);
	
	vec3 world_pos = vec3(0);

	if (tt.x >= 0.0 && tt.y > tt.x) {
		world_pos = camera_pos + camera_dir * tt.x;
		camera_distance = tt.y;
		
		vec3 pos = scatter(camera_pos, camera_dir, tt.x, tt.y);
		if (tt.z >= 0.0 && pos.z > 9e5) {
			pos = scatter(camera_pos, camera_dir, tt.z, tt.w);
		}
		float mask = step(9e5, pos.z);
		t_solid = min(t_solid, length(pos - camera_pos));
		
		float ins = cartesian_density_map(pos * .95, 3);
		vec3 c_cloud = sun_color.rgb;
		c_cloud *= 1. - step(0.1, ins) * .7;
		
		c = mix(c_cloud, c, mask);
	}
	
	c = mix(sky_color.rgb, c, exp(-t_solid * 2e-4));
	return vec4(c, 0);
}

void vertex() {
	POSITION = vec4(VERTEX, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 world_pos = (INV_VIEW_MATRIX * upos / upos.w).xyz;
	float camera_distance = length(world_pos - CAMERA_POSITION_WORLD);
	vec3 camera_dir = normalize(world_pos - CAMERA_POSITION_WORLD);
	
	vec3 screen_color = texture(screen_texture, SCREEN_UV).rgb;
	vec4 res = main(screen_color, CAMERA_POSITION_WORLD, camera_dir, camera_distance);
	ALBEDO = res.xyz;
}
