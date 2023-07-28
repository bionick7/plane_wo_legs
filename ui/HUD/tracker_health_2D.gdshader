shader_type canvas_item;
render_mode unshaded;

uniform vec4 color: source_color = vec4(1);
uniform vec4 regen_color: source_color = vec4(1);

uniform int total_hp;
uniform int current_hp;
uniform float regen_progress: hint_range(0.0, 1.0, 0.01);

uniform float spacing: hint_range(0.0, 1.0, 0.01);
uniform float border: hint_range(0.0, 1.0, 0.01);

void fragment() {
	float total_hp_f = float(total_hp);
	float total_border = spacing + border;
	int current_index = int(UV.x * total_hp_f) + 1;
	vec2 box_coords = fract(UV * vec2(total_hp_f, 1.)) * 2. - 1.;
	float ar = dFdxCoarse(UV.x) / dFdyCoarse(UV.y) * total_hp_f;
	vec2 outer_box_margin = vec2(1.) - spacing * vec2(ar, 1.);
	vec2 inner_box_margin = vec2(1.) - total_border * vec2(ar, 1.);
	float outer_box = 1. - clamp(dot(step(outer_box_margin, abs(box_coords)), vec2(1)), 0., 1.);
	float inner_box = 1. - clamp(dot(step(inner_box_margin, abs(box_coords)), vec2(1)), 0., 1.);
	
	float end_mask = outer_box;
	if (current_hp < current_index) {
		end_mask -= inner_box;
	}
	
	COLOR = color;
	COLOR.a *= end_mask;
	
	if (current_index == current_hp + 1 && inner_box > 0.5) {
		float internal_uv_x = box_coords.x * .5 + .5;  // Renormalize
		float x_border = total_border * ar *.5;
		// remap 0 -> 1 => x_border -> 1 - x_border
		internal_uv_x = (internal_uv_x - x_border) / (1. - 2. * x_border);
		COLOR = mix(COLOR, regen_color, step(internal_uv_x, regen_progress));
	}
}
