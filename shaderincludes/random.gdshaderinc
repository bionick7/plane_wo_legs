
int rand_int(int x) {
    x += x << 10;
    x ^= x >>  6;
    x += x <<  3;
    x ^= x >> 11;
    x += x << 15;
    return x;
}

float rand_float(int seed){
	int rand_int = rand_int(seed);
	return fract(float(rand_int) / 1000000.0);
}

float random_from_vec2(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898,78.233)))*43758.5453123);
}

float rand_at_point(ivec3 pt){
	return rand_float(pt.x * 157 + pt.y * 489 + pt.z);
}

float map_range(float v, float from_min, float from_max, float to_min, float to_max) {
	float n = (v - from_min) / (from_max - from_min);
	return to_min + n * (to_max - to_min);
}

float get_simple_noise(sampler2D noise_texture, vec3 x){
	ivec3 p = ivec3(floor(x));
	vec3 f = fract(x);
	
	float r_000 = rand_at_point(p + ivec3(0,0,0));
	float r_001 = rand_at_point(p + ivec3(0,0,1));
	float r_010 = rand_at_point(p + ivec3(0,1,0));
	float r_011 = rand_at_point(p + ivec3(0,1,1));
	float r_100 = rand_at_point(p + ivec3(1,0,0));
	float r_101 = rand_at_point(p + ivec3(1,0,1));
	float r_110 = rand_at_point(p + ivec3(1,1,0));
	float r_111 = rand_at_point(p + ivec3(1,1,1));
	
	return mix(
		mix(
			mix(r_000, r_001, smoothstep(0.0, 1.0, f.z)),
			mix(r_010, r_011, smoothstep(0.0, 1.0, f.z)),
		f.y),
		mix(
			mix(r_100, r_101, smoothstep(0.0, 1.0, f.z)),
			mix(r_110, r_111, smoothstep(0.0, 1.0, f.z)),
		f.y),
	f.x);
}