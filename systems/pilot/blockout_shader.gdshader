shader_type canvas_item;
render_mode unshaded;

uniform float tunnel: hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float redout: hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float greyout: hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float blackout: hint_range(0.0, 1.0, 0.01) = 0.0;

uniform vec4 redout_tone: source_color = vec4(1,0,0,1);

uniform sampler2D screen: hint_screen_texture;
uniform sampler2D white_noise: repeat_enable, filter_nearest;

void fragment() {
	vec3 color = texture(screen, SCREEN_UV).rgb;
	vec2 uv = UV*1.41 - vec2(.707);
	float rad = dot(uv, uv);
	
	vec3 grey_color = vec3(dot(color, vec3(.333)));
	mat2 rot = mat2(
		vec2(cos(TIME), sin(TIME)),
		vec2(-sin(TIME), cos(TIME))
	);
	float ar = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 noise_coords = rot * (SCREEN_UV * vec2(ar, 1) + TIME * vec2(PI, E));
	float noise = step(1. - tunnel*.3, texture(white_noise, noise_coords).r);
	color = mix(color, grey_color, greyout);
	color = mix(color, vec3(0,0,0), smoothstep(1. - tunnel, 1.0, rad) + noise);
	color = mix(color, redout_tone.rgb, redout);
	color = mix(color, vec3(0,0,0), blackout);
	
	COLOR.rgb = color;
}
