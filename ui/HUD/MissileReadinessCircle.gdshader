shader_type spatial;
render_mode unshaded;

uniform int total_segments;
uniform float outside_radius;
uniform float thickness;
uniform vec4 color: source_color;

uniform float blinking_frequency;

void vertex() {
	float angle = float(VERTEX_ID) / float(total_segments) * PI;
	float radius = mix(outside_radius - thickness, outside_radius, float(VERTEX_ID % 2));
	VERTEX = vec3(cos(angle), sin(angle), 0.0) * radius;
}

void fragment() {
	if (cos(TIME * blinking_frequency * TAU) < 0.0) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
