shader_type spatial;
render_mode unshaded;
//render_mode cull_disabled;

uniform sampler2D noise: hint_default_white;
uniform sampler2D gradient: hint_default_white;
uniform float distortion: hint_range(0.0, 1.0);
uniform float throttle: hint_range(0.0, 1.0) = 0.5;

varying vec2 new_uv;

void vertex() {
	float x_pos = VERTEX.y + .8;
	float y_pos = acos(VERTEX.z) / 3.1415 * -sign(VERTEX.x);
	new_uv = vec2(x_pos * .5 + .25, y_pos / 2. + .5);
}

void fragment() {
	vec2 animated_uv = new_uv + vec2(TIME, 0) * 1. + texture(noise, new_uv).rg  * distortion;
	ALBEDO = vec3(0);
//	ALBEDO.rg = animated_uv;
	vec4 grad = texture(gradient, new_uv + texture(noise, animated_uv).r * .2);
	ALBEDO = grad.rgb;
	ALPHA = grad.a * throttle;
	EMISSION = vec3(5.0);
}