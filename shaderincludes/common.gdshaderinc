
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

float map_range(float v, float from_min, float from_max, float to_min, float to_max) {
	float n = (v - from_min) / (from_max - from_min);
	return to_min + n * (to_max - to_min);
}

mat3 get_rotation_matrix(float p, float r){
	mat3 roll = mat3(
		vec3(cos(r),sin(r), 0),
		vec3(-sin(r),cos(r), 0),
		vec3(0,0, 1)
	);
	mat3 pitch = mat3(
		vec3(cos(p),0,-sin(p)),
		vec3(0,1,0),
		vec3(sin(p),0,cos(p))
	);
	
	return roll * pitch;
}