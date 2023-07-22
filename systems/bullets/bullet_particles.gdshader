shader_type particles;

#include "res://shaderincludes/random.gdshaderinc"

uniform vec3 global_start_velocity = vec3(0);
uniform bool include_centrifugal = true;
uniform bool include_coreolis = true;

void start() {
	VELOCITY = global_start_velocity;
	float vel_length = length(global_start_velocity);
	float variance = vel_length * DELTA;
	float per_frame = float(NUMBER) * DELTA / LIFETIME;
	float offset = fract(float(INDEX) / per_frame) * variance;
	TRANSFORM = EMISSION_TRANSFORM;
	TRANSFORM[3].xyz += offset * global_start_velocity / vel_length;
}

void process() {
	vec3 ang_vel = vec3(0, 0, -sqrt(9.81 / 4000.));
	vec3 acc = vec3(0);
	if (include_centrifugal) {
		vec3 pos = TRANSFORM[3].xyz;
		acc += - cross(ang_vel, cross(ang_vel, pos));
	}
	if (include_coreolis) {
		acc += - 2. * cross(ang_vel, VELOCITY);
	}
	VELOCITY += acc * DELTA;
}
