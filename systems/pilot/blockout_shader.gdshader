shader_type canvas_item;
render_mode unshaded;

uniform float tunnel: hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float redout: hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float greyout: hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float blackout: hint_range(0.0, 1.0, 0.01) = 0.0;

uniform vec4 redout_tone: source_color = vec4(1,0,0,1);

uniform sampler2D screen: hint_screen_texture;

void fragment() {
	vec3 color = texture(screen, SCREEN_UV).rgb;
	vec2 uv = UV*1.41 - vec2(.707);
	float rad = dot(uv, uv);
	
	vec3 grey_color = vec3(dot(color, vec3(.333)));
	color = mix(color, grey_color, greyout);
	color = mix(color, vec3(0,0,0), smoothstep(1. - tunnel, 1.0, rad));
	color = mix(color, redout_tone.rgb, redout);
	color = mix(color, vec3(0,0,0), blackout);
	
	COLOR.rgb = color;
}
