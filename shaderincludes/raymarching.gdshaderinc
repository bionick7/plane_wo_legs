
#ifndef MAX_DIST
#define MAX_DIST 1e4
#endif

#ifndef MAX_ITER
#define MAX_ITER 256
#endif

#ifndef NORMAL_EPSILON
#define NORMAL_EPSILON 5e-4
#endif

#ifndef RAYMARCH_DELTA
#define RAYMARCH_DELTA 1e-4
#endif

#ifndef MAP_FUNC
#define MAP_FUNC __default_mapper
#endif

float __default_mapper(vec3 p) { return 0.0; }

vec3 calcNormal( in vec3 pos ) {
    vec2 e = vec2(1.0,-1.0)*0.5773;
    return normalize( e.xyy*MAP_FUNC(pos + e.xyy*NORMAL_EPSILON) + 
					  e.yyx*MAP_FUNC(pos + e.yyx*NORMAL_EPSILON) + 
					  e.yxy*MAP_FUNC(pos + e.yxy*NORMAL_EPSILON) + 
					  e.xxx*MAP_FUNC(pos + e.xxx*NORMAL_EPSILON) );
}

float signed_raymarch(vec3 ro, vec3 rd, float tmax, float sign_) {
	float t = 0.0;
	for(int i = 0; i < MAX_ITER; i++){
		vec3 pos = ro + t*rd;
		float h = sign_ * MAP_FUNC(pos);
		if( h<RAYMARCH_DELTA || t>tmax ) break;
		t += h;
	}
	return t;
}

float raymarch(vec3 ro, vec3 rd) {
	return signed_raymarch(ro, rd, MAX_DIST, 1.0);
}
