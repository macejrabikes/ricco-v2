shader_type canvas_item;
// Obrazovka počas spomalenia: odfarbí sa do studenej „duchovskej“ modrej a okraje stmavnú.
// Podľa Godot docs: tutorials/shaders/screen-reading_shaders (hint_screen_texture + SCREEN_UV).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint = vec3(0.55, 0.85, 1.0);

void fragment() {
	vec3 c = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	float gray = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 ghost = gray * tint * 1.15;
	vec3 outc = mix(c, ghost, strength * 0.7);
	vec2 d = (SCREEN_UV - vec2(0.5)) * vec2(1.0, 0.75);
	float vignette = smoothstep(0.3, 0.72, length(d));
	outc = mix(outc, outc * vec3(0.22, 0.36, 0.5), vignette * strength * 0.85);
	COLOR = vec4(outc, 1.0);
}
