shader_type spatial;
render_mode unshaded, cull_disabled;

//#define DITHER

uniform sampler2D noise;
uniform float cutoff: hint_range(0.0, 1.0, 0.001);
uniform float cloud_cover_speed = 0.01;

global uniform vec3 sun_dir;
global uniform float cloud_anim_time;

#ifdef DITHER
#include "random.gdshaderinc"
float bayer2(vec2 a) {
    a = floor(a);
    return fract(a.x / 2. + a.y * a.y * .75);
}

#define bayer4(a)   (bayer2 (.5 *(a)) * .25 + bayer2(a))
#define bayer8(a)   (bayer4 (.5 *(a)) * .25 + bayer2(a))
#define bayer16(a)  (bayer8 (.5 *(a)) * .25 + bayer2(a))
#define bayer32(a)  (bayer16(.5 *(a)) * .25 + bayer2(a))
#define bayer64(a)  (bayer32(.5 *(a)) * .25 + bayer2(a))
#endif // DITHER

float angle(vec2 v) {
	float angle = atan(v.y / v.x) + PI/2.0;
	if (v.x < 0.0) angle += PI;
	return angle;
}

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

float get_wall_shadow(vec3 from) {
	vec2 walls = raytrace_inf_cylinder(from, sun_dir, 4e3);
	float max_dist = max(walls.x, walls.y);  // assumes we're inside the cylinder
	vec3 wall_point = from + sun_dir * max_dist;
	return smoothstep(0.6667, 0.333, abs(mod(angle(wall_point.xy) + PI*1.6667, PI*.6667) - PI*.3333));
}

void fragment() {
	vec2 uv = (UV - vec2(0.12, 0.26)) * vec2(1.0, 1.25);
	uv.x += cloud_anim_time * cloud_cover_speed;
	float cloud_texture = texture(noise, uv).r;
	
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wall_shadow = get_wall_shadow(world_pos);
#ifdef DITHER
	float cloud_alpha = smoothstep(0.37, 0.45, cloud_texture);
	//float dither_func = random_from_vec2(FRAGCOORD.xy + fract(TIME * 0.1));
	float dither_func = bayer2(FRAGCOORD.xy);
	if (dither_func < cloud_alpha) {
		discard;
	}
#else
	float cloud_alpha = cloud_texture;
	if (1. - (1. - cloud_alpha) * (1. - wall_shadow) < cutoff) {
		discard;
	}
#endif // DITHER
}
