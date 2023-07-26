shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color: source_color = vec4(1);

uniform int total_hp;
uniform int current_hp;

uniform float spacing: hint_range(0.0, 1.0, 0.01);
uniform float border: hint_range(0.0, 1.0, 0.01);

void fragment() {
	int current_index = total_hp - int(UV.x * float(total_hp));
	vec2 box_coords = fract(UV * vec2(ivec2(total_hp, 1))) * 2. - 1.;
	float outer_box_margin = 1. - spacing;
	float inner_box_margin = 1. - spacing - border;
	float outer_box = 1. - clamp(dot(step(vec2(outer_box_margin), abs(box_coords)), vec2(1)), 0., 1.);
	float inner_box = 1. - clamp(dot(step(vec2(inner_box_margin), abs(box_coords)), vec2(1)), 0., 1.);
	
	float end_mask = outer_box;
	if (current_hp < current_index) {
		end_mask -= inner_box;
	}
	
	ALBEDO = color.rgb;
	ALPHA = end_mask;
}
