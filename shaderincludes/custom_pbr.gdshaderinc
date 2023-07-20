#define CUSTOM_LIGHTING

float D_GGX(float NoH, float rough) {
    float a = NoH * rough;
    float k = rough / (1.0 - NoH * NoH + a * a);
    return k * k;
}

vec3 F_Schlick(float u, vec3 f0) {
    return f0 + (vec3(1.0) - f0) * pow(1.0 - u, 5.0);
}

float V_SmithGGXCorrelated(float NoV, float NoL, float a) {
    float a2 = a * a;
    float GGXL = NoV * sqrt((-NoL * a2 + NoL) * NoL + a2);
    float GGXV = NoL * sqrt((-NoV * a2 + NoV) * NoV + a2);
    return 0.5 / (GGXV + GGXL);
}

vec3 get_diffuse_lighting(vec3 n, vec3 l, vec3 p_albedo) {
    return p_albedo * clamp(dot(n, l), 0., 1.);
}

vec3 get_specular_lighting(vec3 n, vec3 l, vec3 v, float rough) {
    vec3 h = normalize(v + l);

    float NoV = abs(dot(n, v)) + 1e-5;
    float NoL = clamp(dot(n, l), 0.0, 1.0);
    float NoH = clamp(dot(n, h), 0.0, 1.0);
    float LoH = clamp(dot(l, h), 0.0, 1.0);

	vec3 f0 = vec3(0.03);

    float D = D_GGX(NoH, rough);
    vec3  F = F_Schlick(LoH, f0);
    float V = V_SmithGGXCorrelated(NoV, NoL, rough);

	F = vec3(1);

    // specular BRDF
    return D * F * V;
}

float get_specular_simple(vec3 n, vec3 l, vec3 v, float rough) {
	// no Fshlick
    vec3 h = normalize(v + l);

    float NoV = abs(dot(n, v)) + 1e-5;
    float NoL = clamp(dot(n, l), 0.0, 1.0);
    float NoH = clamp(dot(n, h), 0.0, 1.0);
    float LoH = clamp(dot(l, h), 0.0, 1.0);

	vec3 f0 = vec3(0.03);

    float D = D_GGX(NoH, rough);
    float V = V_SmithGGXCorrelated(NoV, NoL, rough);

    return D * V;
}
