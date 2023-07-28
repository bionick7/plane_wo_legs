//#define CLOUD_LIGHTING
//#define CLOUD_RECT

uniform float cloud_cover_speed = 0.01;

global uniform vec3 sun_dir = vec3(0, 1.0, 0);
global uniform sampler2D cloud_cover;
global uniform float cloud_anim_time;
global uniform float layer_mid;
global uniform float layer_thickness;

const float powder = 1e-1;
const float beer = 6e-3;

float angle(vec2 v) {
	float angle = atan(v.y / v.x) + PI/2.0;
	if (v.x < 0.0) angle += PI;
	return angle;
}

#ifdef CLOUD_RECT
vec3 global_to_cylindrical(vec3 v) {
	return v * 1e-3;
}

vec3 cylindrical_to_global(vec3 v) {
	return v * 1e3;
}
#else
vec3 global_to_cylindrical(vec3 v) {
	return vec3(angle(v.xy), (layer_mid - length(v.xy)) * 1e-3, v.z * 3.33333e-4);
}

vec3 cylindrical_to_global(vec3 v) {
	float r = layer_mid - v.y * 1e3;
	return vec3(sin(v.x) * r, -cos(v.x) * r, v.z * 3e3);
}
#endif

vec2 raytrace_inf_cylinder(vec3 p, vec3 dir, float radius) {
	float a = dot(dir.xy, dir.xy);
	float b = 2.0 * dot(p.xy, dir.xy);
	float c = dot(p.xy, p.xy) - radius*radius;
	float delta = b*b - 4.0*a*c;
	if (delta <= 0.0) {
		return vec2(0);
	}
	float t1 = (-b - sqrt(delta)) / (2.0*a);
	float t2 = (-b + sqrt(delta)) / (2.0*a);
	return vec2(t1, t2);
}

vec4 find_cloud_layer_limits(vec3 ro, vec3 rd, float max_dist) {
	vec2 t_outer = raytrace_inf_cylinder(ro, rd, layer_mid + layer_thickness * 0.5);
	vec2 t_inner = raytrace_inf_cylinder(ro, rd, layer_mid - layer_thickness * 0.5);
	if (dot(t_outer, t_outer) + dot(t_inner, t_inner) == 0.0) {
		// both are zero -> no crossing
		return vec4(-1);
	}
	
	vec4 t_sorted = vec4(t_outer, t_inner).xzwy;
	if (t_sorted.x > t_sorted.w) {
		t_sorted = t_sorted.wzyx;
	}
	
	if (dot(t_sorted.yz, t_sorted.yz) == 0.0) {
		// any of both are zero -> only crosses t_outer
		return vec4(clamp(t_sorted.xw, vec2(0.001), vec2(max_dist)), vec2(-1));
	}
	
	if (t_sorted.w < 0.0) {
		return vec4(-1);
	}
	if (t_sorted.y <= 0.0) {
		return vec4(clamp(t_sorted.zw, vec2(0.001), vec2(max_dist)), vec2(-1));
	}
	return clamp(t_sorted, vec4(0.001), vec4(max_dist));
}

vec4 find_rect_limits(vec3 ro, vec3 rd, vec3 box_extents, float max_dist) { 
	vec3 t1 = (-box_extents - ro) / rd;
	vec3 t2 =  (box_extents - ro) / rd;

	float tmin = max(max(min(t1.x, t2.x), min(t1.y, t2.y)), min(t1.z, t2.z));
	float tmax = min(min(max(t1.x, t2.x), max(t1.y, t2.y)), max(t1.z, t2.z));

	if (tmax < 0.0) {
	    return vec4(-1);
	}
	if (tmin > tmax) {
	    return vec4(-1);
	}

	return vec4(clamp(vec2(tmin, tmax), vec2(0), vec2(max_dist)), vec2(-1));
}

float get_coverage(vec2 uv) {
	//return 1.0;
	uv /= TAU;
	uv += vec2(cloud_cover_speed, 0) * cloud_anim_time;
	return smoothstep(0.4, 1.0, texture(cloud_cover, uv).r);
}

float beer_f(float x) {
	return exp(-beer * x);
}

float powder_beer(float x) {
	float powder_f = 1.0 - exp(-powder * x);
	float beer_f = exp(-beer * x);
	return beer_f * powder_f;
}

float get_light_at_point(vec3 p_glob, float density_at_p) {
	const vec2 AVG = vec2(.5, 0);
	vec3 light_dir = normalize(vec3(-p_glob.xy, 0.));
	vec2 walls = raytrace_inf_cylinder(p_glob, light_dir, 4e3);
	float max_dist = max(walls.x, walls.y);  // assumes we're inside the cylinder
	vec3 wall_point = p_glob + sun_dir * max_dist;
	float wall_shadow = smoothstep(0.6667, 0.333, abs(mod(angle(wall_point.xy) + PI*1.6667, PI*.6667) - PI*.3333));
	
	vec4 tt = find_cloud_layer_limits(p_glob, sun_dir, max_dist);
	vec3 sample_point = p_glob + sun_dir * max(dot(tt, AVG.xxyy), dot(tt, AVG.yyxx));
	float cov = get_coverage(global_to_cylindrical(sample_point).xz);
		
	#ifdef CLOUD_RECT
		float depth = layer_thickness*.5 - p_loc.y * 1e3;
	#else
		float depth = dot(tt, vec4(-density_at_p, density_at_p, -cov, cov));  // Cryptic, but cool
	#endif  // CLOUD_RECT
	
	//return 1.0 - wall_shadow;
	float cloud_shadow = beer_f(depth);
	//cloud_shadow = 1. - (1. - cloud_shadow)*(1. - cloud_shadow);
	return pow(cloud_shadow, 0.3) * (1.0 - wall_shadow);
}